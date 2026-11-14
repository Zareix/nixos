{
  globals,
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.zrx.mercure;
  incus = "${config.virtualisation.incus.clientPackage}/bin/incus";
  dataVolume = "${cfg.name}-data";

  # Passerelle du bridge : 10.42.0.1 pour 10.42.0.0/24 (robuste au changement de /24).
  networkGateway = let
    first3 = lib.take 3 (lib.splitString "." (lib.head (lib.splitString "/" cfg.networkCidr)));
  in "${lib.concatStringsSep "." first3}.1/24";
in {
  options.zrx.mercure = {
    enable = lib.mkEnableOption "Hermes Agent running in an Incus VM with a Debian guest";

    name = lib.mkOption {
      type = lib.types.str;
      default = "mercure";
      description = "Incus instance name.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "images:debian/13";
      description = "Incus image for the guest. Must come from the images: remote so the incus-agent is preinstalled.";
    };

    cpu = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "vCPU count.";
    };

    memory = lib.mkOption {
      type = lib.types.str;
      default = "6GiB";
      description = "Memory limit (Incus size string).";
    };

    storagePool = lib.mkOption {
      type = lib.types.str;
      default = "mercure";
      description = "Incus storage pool name (created by preseed).";
    };

    storageSource = lib.mkOption {
      type = lib.types.str;
      default = "/data/apps/incus";
      description = "Directory backing the pool.";
    };

    ui = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Serve the Incus web UI (incus-ui-canonical) on /ui/.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8443;
        description = "TLS port for the Incus API and web UI.";
      };
      tailnetOnly = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Only open the UI port on tailscale0 (règle zrx.sh : privé = tailnet).";
      };
    };

    dataSize = lib.mkOption {
      type = lib.types.str;
      default = "120GiB";
      description = "Size of the block volume mounted on /opt/data inside the guest.";
    };

    rootSize = lib.mkOption {
      type = lib.types.str;
      default = "60GiB";
      description = "Size of the system disk.";
    };

    networkName = lib.mkOption {
      type = lib.types.str;
      default = "incusbr0";
      description = "Bridge created by preseed.";
    };

    networkCidr = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.0/24";
      description = "Bridge subnet. Do not collide with the LAN.";
    };

    ip = lib.mkOption {
      type = lib.types.str;
      default = "10.42.0.10";
      description = "Static address reserved for the appliance (DHCP reservation on the bridge).";
    };

    userData = lib.mkOption {
      type = lib.types.path;
      description = "cloud-init user-data file for the guest.";
    };

    # Pas de provisioning automatisé : l'intérieur de la VM (paquets, Hermes,
    # unité systemd) s'installe à la main. Les étapes minimales sont dans
    # hosts/jupiter/mercure/README.md.
  };

  config = lib.mkIf cfg.enable {
    # Le pool "dir" exige que son répertoire existe avant le preseed.
    systemd.tmpfiles.rules = [
      "d ${cfg.storageSource} 0711 root root -"
    ];

    virtualisation.incus = {
      enable = true;
      ui.enable = cfg.ui.enable;
      preseed = {
        # incusd n'écoute que sur le socket unix par défaut : l'UI (comme l'API
        # distante) exige core.https_address.
        config = lib.optionalAttrs cfg.ui.enable {
          "core.https_address" = "0.0.0.0:${toString cfg.ui.port}";
        };
        storage_pools = [
          {
            name = cfg.storagePool;
            driver = "dir";
            config.source = cfg.storageSource;
          }
        ];
        networks = [
          {
            name = cfg.networkName;
            type = "bridge";
            config = {
              "ipv4.address" = networkGateway;
              "ipv4.nat" = "true";
              "ipv6.address" = "none";
            };
          }
        ];
        # Profil explicite : sans lui, la présence de eth0 dépend du profil
        # "default" créé (ou non) par `incus admin init`.
        profiles = [
          {
            name = "${cfg.name}-vm";
            devices = {
              root = {
                type = "disk";
                path = "/";
                pool = cfg.storagePool;
                size = cfg.rootSize;
              };
              eth0 = {
                type = "nic";
                name = "eth0";
                network = cfg.networkName;
              };
            };
          }
        ];
      };
    };

    # Le client incus pour l'admin humain (groupe incus-admin).
    users.users.${globals.username}.extraGroups = ["incus-admin"];

    # UI + API : jamais sur le LAN, uniquement via le tailnet (convention zrx.sh).
    networking.firewall.interfaces = lib.mkIf (cfg.ui.enable && cfg.ui.tailnetOnly) {
      tailscale0.allowedTCPPorts = [cfg.ui.port];
    };

    # 1. Création de l'instance (une seule fois) puis démarrage.
    systemd.services.mercure = {
      description = "Ensure the Hermes VM exists and is running";
      wantedBy = ["multi-user.target"];
      wants = ["incus-preseed.service"];
      after = ["incus.service" "incus-preseed.service" "network-online.target"];
      path = [pkgs.coreutils pkgs.gnugrep];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "900";
      };
      script = ''
        set -euo pipefail
        name=${cfg.name}

        if ! ${incus} info "$name" >/dev/null 2>&1; then
          echo "création de l'instance $name"
          ${incus} init ${cfg.image} "$name" --vm --profile ${cfg.name}-vm \
            --config limits.cpu=${toString cfg.cpu} \
            --config limits.memory=${cfg.memory} \
            --config boot.autostart=true \
            --config boot.autostart.priority=20 \
            --config cloud-init.user-data="$(cat ${cfg.userData})"

          ${incus} storage volume create ${cfg.storagePool} ${dataVolume} \
            --type=block size=${cfg.dataSize}
          ${incus} config device add "$name" data disk \
            pool=${cfg.storagePool} source=${dataVolume}

          # réservation DHCP : le guest garde toujours la même adresse
          # (device local ou hérité du profil "default" selon la version d'incus)
          ${incus} config device set "$name" eth0 ipv4.address=${cfg.ip} 2>/dev/null \
            || ${incus} config device override "$name" eth0 ipv4.address=${cfg.ip} \
            || echo "ATTENTION : réservation d'IP non appliquée, voir 'incus config show $name'"
        fi

        ${incus} start "$name" || true
      '';
    };
  };
}
