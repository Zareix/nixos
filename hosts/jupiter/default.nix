{
  pkgs,
  globals,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    # mercure : VM Debian pour Hermes Agent (remplace le conteneur Docker jupiter/hermes-agent).
    # Voir hosts/jupiter/mercure/README.md pour l'ordre des opérations.
    incus = {
      enable = true;
      storagePools.default.source = "/data/apps/incus";
      networks.incusbr0.cidr = "10.42.0.0/24";
      vms.mercure = {
        image = "images:debian/13";
        cpu = 4;
        memory = "6GiB";
        rootSize = "60GiB";
        pool = "default";
        network = "incusbr0";
        ip = "10.42.0.10";
        userData = pkgs.writeText "mercure-user-data.yaml" (import ./mercure/user-data.nix {inherit globals;});
        # Les données restent des fichiers sur jupiter (restic de l'hôte les voit
        # directement) ; le disque système seul vit dans le pool incus.
        shares = [
          {
            name = "data";
            source = "/data/apps/mercure";
            path = "/opt/data";
          }
        ];
      };
    };
    shareServer = {
      enable = true;
      shareFolder = "/mnt/mass/share";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };
  console.keyMap = "fr";

  networking.networkmanager.enable = true;
  networking = {
    interfaces = {
      eno1 = {
        ipv4.addresses = [
          {
            address = "192.168.31.205";
            prefixLength = 24;
          }
        ];
        wakeOnLan.enable = true;
      };
    };
    defaultGateway = {
      interface = "eno1";
      address = "192.168.31.1";
    };
  };

  system.stateVersion = "26.05";
}
