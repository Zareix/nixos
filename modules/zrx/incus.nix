{
  globals,
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.zrx.incus;
  incus = "${config.virtualisation.incus.clientPackage}/bin/incus";
  grep = "${pkgs.gnugrep}/bin/grep";

  # 10.42.0.0/24 -> 10.42.0.1/24
  gateway = cidr: let
    first3 = lib.take 3 (lib.splitString "." (lib.head (lib.splitString "/" cidr)));
  in "${lib.concatStringsSep "." first3}.1/24";

  # Un profil par VM : disque racine + NIC. Déclaré explicitement parce que
  # `incus admin init --preseed` ne crée pas forcément de profil "default",
  # et une instance sans NIC boote sans réseau.
  profiles =
    lib.mapAttrsToList (name: vm: {
      name = "${name}-vm";
      devices = {
        root = {
          type = "disk";
          path = "/";
          pool = vm.pool;
          size = vm.rootSize;
        };
        eth0 = {
          type = "nic";
          name = "eth0";
          network = vm.network;
        };
      };
    })
    cfg.vms;

  # Volumes bloc supplémentaires + attachement, idempotents.
  volumeSetup = name: vm:
    lib.concatMapStringsSep "\n" (vol: ''
      ${incus} storage volume list ${vm.pool} --format csv -c n | ${grep} -qx "${vol.name}" \
        || ${incus} storage volume create ${vm.pool} ${vol.name} --type=block size=${vol.size}
      ${incus} config device list "$name" | ${grep} -qx "${vol.name}" \
        || ${incus} config device add "$name" ${vol.name} disk pool=${vm.pool} source=${vol.name} \
        || echo "ATTENTION : volume ${vol.name} non attaché à $name"
    '')
    vm.dataVolumes;

  # Réservation DHCP : la sous-commande dépend de la version d'incus.
  ipSetup = vm:
    if vm.ip == null
    then ""
    else ''
      ${incus} config device set "$name" eth0 ipv4.address=${vm.ip} 2>/dev/null \
        || ${incus} config device override "$name" eth0 ipv4.address=${vm.ip} \
        || echo "ATTENTION : réservation d'IP non appliquée (voir 'incus config show $name')"
    '';

  mkService = name: vm: {
    description = "Ensure the Incus VM ${name} exists, is configured and running";
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
      name=${name}

      if ! ${incus} info "$name" >/dev/null 2>&1; then
        echo "création de l'instance $name"
        ${incus} init ${vm.image} "$name" --vm --profile ${name}-vm \
          --config boot.autostart=${lib.boolToString vm.autostart} \
          --config cloud-init.user-data="$(cat ${vm.userData})"
      fi

      # Réconciliation : ces valeurs sont réappliquées à chaque rebuild
      # (cpu/memory/autostart ne sont pas figés à la création).
      ${incus} config set "$name" limits.cpu=${toString vm.cpu}
      ${incus} config set "$name" limits.memory=${vm.memory}
      ${incus} config set "$name" boot.autostart=${lib.boolToString vm.autostart}

      ${volumeSetup name vm}
      ${ipSetup vm}

      ${incus} start "$name" || true
    '';
  };
in {
  options.zrx.incus = {
    enable = lib.mkEnableOption "Incus (hyperviseur + VM déclarées)";

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

    # Attention : le preseed ne s'applique qu'à l'initialisation d'incus.
    # Ajouter un pool ou un réseau après coup ne crée rien — passer par
    # `incus storage create` / `incus network create` sur l'hôte.
    storagePools = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          driver = lib.mkOption {
            type = lib.types.str;
            default = "dir";
            description = "Incus storage driver.";
          };
          source = lib.mkOption {
            type = lib.types.str;
            description = "Backing path (driver dir). Created via tmpfiles if missing.";
          };
        };
      });
      default = {};
      description = "Storage pools, keyed by pool name.";
    };

    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          cidr = lib.mkOption {
            type = lib.types.str;
            description = "Subnet of the bridge (the gateway is .1 of the first three octets).";
          };
          nat = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable NAT on the bridge.";
          };
        };
      });
      default = {};
      description = "Bridge networks, keyed by network name.";
    };

    vms = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          image = lib.mkOption {
            type = lib.types.str;
            description = ''
              Incus image, e.g. "images:debian/13". Must come from a remote whose
              images ship the incus-agent, so `incus exec` works from first boot.
            '';
          };
          cpu = lib.mkOption {
            type = lib.types.ints.positive;
            default = 2;
            description = "vCPU count, reconciled on every rebuild.";
          };
          memory = lib.mkOption {
            type = lib.types.str;
            default = "2GiB";
            description = "Memory limit (Incus size string), reconciled on every rebuild.";
          };
          rootSize = lib.mkOption {
            type = lib.types.str;
            default = "20GiB";
            description = "System disk size. Applied at creation only.";
          };
          pool = lib.mkOption {
            type = lib.types.str;
            default = "default";
            description = "Storage pool for the root disk and the data volumes.";
          };
          network = lib.mkOption {
            type = lib.types.str;
            default = "incusbr0";
            description = "Bridge the VM is attached to.";
          };
          ip = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "DHCP reservation on the bridge. null = dynamic.";
          };
          autostart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Start the VM with incusd.";
          };
          userData = lib.mkOption {
            type = lib.types.path;
            description = ''
              cloud-init user-data. Never put secrets here: it lands in the
              instance config (`incus config show`, `incus export`).
            '';
          };
          dataVolumes = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Volume name, also used as the device name.";
                };
                size = lib.mkOption {
                  type = lib.types.str;
                  description = "Block volume size, e.g. \"120GiB\". Applied at creation only.";
                };
              };
            });
            default = [];
            description = ''
              Extra block volumes (content-type block, attached without a path:
              the guest sees them as /dev/vdX). Not formatted — mkfs is a manual,
              explicit decision.
            '';
          };
        };
      });
      default = {};
      description = "VMs, keyed by instance name.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Les pools "dir" exigent que leur répertoire existe avant le preseed.
    systemd.tmpfiles.rules =
      lib.mapAttrsToList (name: pool: "d ${pool.source} 0711 root root -")
      cfg.storagePools;

    virtualisation.incus = {
      enable = true;
      ui.enable = cfg.ui.enable;
      preseed = {
        # incusd n'écoute que sur le socket unix par défaut : l'UI (comme l'API
        # distante) exige core.https_address.
        config = lib.optionalAttrs cfg.ui.enable {
          "core.https_address" = "0.0.0.0:${toString cfg.ui.port}";
        };
        storage_pools =
          lib.mapAttrsToList (name: pool: {
            inherit name;
            driver = pool.driver;
            config.source = pool.source;
          })
          cfg.storagePools;
        networks =
          lib.mapAttrsToList (name: net: {
            inherit name;
            type = "bridge";
            config = {
              "ipv4.address" = gateway net.cidr;
              "ipv4.nat" = lib.boolToString net.nat;
              "ipv6.address" = "none";
            };
          })
          cfg.networks;
        profiles = profiles;
      };
    };

    # Le client incus pour l'admin humain (groupe incus-admin).
    users.users.${globals.username}.extraGroups = ["incus-admin"];

    # UI + API : jamais sur le LAN, uniquement via le tailnet (convention zrx.sh).
    networking.firewall.interfaces = lib.mkIf (cfg.ui.enable && cfg.ui.tailnetOnly) {
      tailscale0.allowedTCPPorts = [cfg.ui.port];
    };

    systemd.services = lib.mapAttrs' (name: vm: lib.nameValuePair "incus-vm-${name}" (mkService name vm)) cfg.vms;
  };
}
