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

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.networkmanager.enable = true;
}
