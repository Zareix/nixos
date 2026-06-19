{
  imports = [
    ./hardware-configuration.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
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
      eno1.ipv4.addresses = [
        {
          address = "192.168.31.205";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      interface = "eno1";
      address = "192.168.31.1";
    };
  };

  system.stateVersion = "26.05";
}
