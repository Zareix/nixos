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

  # Un profil par VM : disque racine + NIC. `incus admin init --preseed` ne crée
  # pas de profil "default", et une instance sans NIC boote sans réseau.
  profiles =
    lib.mapAttrsToList (name: vm: {
      name = "${name}-vm";
      devices = {
        root = {
          type = "disk";
          path = "/";
          pool = "default";
          size = vm.rootSize;
        };
        eth0 = {
          type = "nic";
          name = "eth0";
          network = "incusbr0";
        };
      };
    })
    cfg.vms;

  # Partages de répertoires de l'hôte montés dans l'invité (9p ou virtiofs).
  # Les fichiers restent lisibles sur l'hôte : un restic hôte les sauvegarde
  # normalement, sans lire d'image disque.
  shareSetup = name: vm:
    lib.concatMapStringsSep "\n" (share: ''
      ${incus} config device list "$name" | ${grep} -qx "${share.name}" \
        || ${incus} config device add "$name" ${share.name} disk source=${share.source} path=${share.path} \
        || echo "ATTENTION : partage ${share.name} non monté dans $name"
    '')
    vm.shares;

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
          --config cloud-init.user-data="$(cat ${vm.userData})"
      fi

      # Réconciliation : ces valeurs sont réappliquées à chaque rebuild
      # (cpu/memory ne sont pas figés à la création).
      ${incus} config set "$name" limits.cpu=${toString vm.cpu}
      ${incus} config set "$name" limits.memory=${vm.memory}
      ${incus} config set "$name" boot.autostart=true

      ${shareSetup name vm}

      ${incus} start "$name" || true
    '';
  };
in {
  options.zrx.incus = {
    enable = lib.mkEnableOption "Incus (hyperviseur + VM déclarées)";

    storageSource = lib.mkOption {
      type = lib.types.str;
      description = "Directory backing the `dir` pool `default`. Created via tmpfiles if missing.";
    };

    network = lib.mkOption {
      type = lib.types.str;
      description = "Address of the `incusbr0` NAT bridge, e.g. \"10.42.0.1/24\".";
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
          userData = lib.mkOption {
            type = lib.types.path;
            description = ''
              cloud-init user-data. Never put secrets here: it lands in the
              instance config (`incus config show`, `incus export`).
            '';
          };
          shares = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Device name (must be unique inside the instance).";
                };
                source = lib.mkOption {
                  type = lib.types.str;
                  description = "Directory on the host to expose. Created if missing.";
                };
                path = lib.mkOption {
                  type = lib.types.str;
                  description = "Mount point inside the guest.";
                };
              };
            });
            default = [];
            description = ''
              Host directories shared into the guest (9p or virtiofs, incus
              decides). The data stays plain files on the host, so a host-side
              backup tool can read it directly.
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
      ["d ${cfg.storageSource} 0711 root root -"]
      ++ lib.concatLists (lib.mapAttrsToList (
          _: vm:
          # 1000:1000 = l'utilisateur cloud-init de l'invité (renommé par vars.nix).
            map (share: "d ${share.source} 0750 1000 1000 -")
            vm.shares
        )
        cfg.vms);

    virtualisation.incus = {
      enable = true;
      ui.enable = true;
      # Le preseed ne s'applique qu'à l'initialisation d'incus : modifier le pool
      # ou le bridge après coup se fait à la main (`incus storage|network edit`).
      preseed = {
        # incusd n'écoute que sur le socket unix par défaut : l'UI (comme l'API
        # distante) exige core.https_address.
        config."core.https_address" = "0.0.0.0:8443";
        storage_pools = [
          {
            name = "default";
            driver = "dir";
            config.source = cfg.storageSource;
          }
        ];
        networks = [
          {
            name = "incusbr0";
            type = "bridge";
            config = {
              "ipv4.address" = cfg.network;
              "ipv4.nat" = "true";
              "ipv6.address" = "none";
            };
          }
        ];
        profiles = profiles;
      };
    };

    users.users.${globals.username}.extraGroups = ["incus-admin"];

    systemd.services = lib.mapAttrs' (name: vm: lib.nameValuePair "incus-vm-${name}" (mkService name vm)) cfg.vms;
  };
}
