{
  imports = [
    ./hardware-configuration.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    # VM Ubuntu pour Hermes Agent (remplace le conteneur Docker jupiter/hermes-agent).
    # Voir hosts/jupiter/hermes-vm/README.md pour l'ordre des opérations.
    hermesVm = {
      enable = true;
      userData = ./hermes-vm/user-data.yaml;
      provisionScript = ./hermes-vm/provision.sh;
      # envFile = config.sops.secrets."hermes-vm-env".path;
      #   -> nécessite { config, ... }: en tête de fichier + la clé dans secrets/common.yaml
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
