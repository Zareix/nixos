{
  globals,
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.zrx.hermesVm;
  incus = "${config.virtualisation.incus.clientPackage}/bin/incus";
  dataVolume = "${cfg.name}-data";

  # Passerelle du bridge : 10.42.0.1 pour 10.42.0.0/24 (robuste au changement de /24).
  networkGateway = let
    first3 = lib.take 3 (lib.splitString "." (lib.head (lib.splitString "/" cfg.networkCidr)));
  in "${lib.concatStringsSep "." first3}.1/24";
  pushEnv =
    if cfg.envFile == null
    then "echo 'envFile non configuré : /etc/hermes/hermes.env ne sera pas poussé'"
    else "${incus} file push ${cfg.envFile} \"$name/root/hermes.env\" --mode 0600";
in {
  options.zrx.hermesVm = {
    enable = lib.mkEnableOption "Hermes Agent running in an Incus VM with an Ubuntu LTS guest";

    name = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
      description = "Incus instance name.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "images:ubuntu/24.04";
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
      default = "hermes";
      description = "Incus storage pool name (created by preseed).";
    };

    storageSource = lib.mkOption {
      type = lib.types.str;
      default = "/data/apps/incus";
      description = "Directory backing the pool.";
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

    provisionScript = lib.mkOption {
      type = lib.types.path;
      description = "Script pushed into the guest and run as root (idempotent).";
    };

    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Host path of the decrypted dotenv file pushed to the guest as
        /etc/hermes/hermes.env. Typically `config.sops.secrets."hermes-vm-env".path`.
        Leave null until the sops key exists, otherwise activation fails.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.incus = {
      enable = true;
      preseed = {
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

    # 1. Création de l'instance (une seule fois) puis démarrage.
    systemd.services.hermes-vm = {
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

    # 2. Provisioning : attend cloud-init, pousse les scripts, exécute.
    systemd.services.hermes-vm-provision = {
      description = "Provision the Hermes VM (packages, /opt/data, Hermes install)";
      wantedBy = ["multi-user.target"];
      wants = ["hermes-vm.service"];
      after = ["hermes-vm.service" "network-online.target"];
      path = [pkgs.coreutils pkgs.gnugrep];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "3600";
      };
      script = ''
        set -euo pipefail
        name=${cfg.name}

        # le premier boot (agent + cloud-init) prend une minute ou deux
        for _ in $(seq 1 60); do
          if ${incus} exec "$name" -- true >/dev/null 2>&1; then break; fi
          sleep 5
        done
        ${incus} exec "$name" -- cloud-init status --wait >/dev/null 2>&1 || true

        ${incus} file push ${cfg.provisionScript} "$name/root/provision.sh" --mode 0755
        ${pushEnv}
        ${incus} exec "$name" -- bash /root/provision.sh
      '';
    };
  };
}
