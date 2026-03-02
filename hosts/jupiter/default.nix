{
  imports = [
    ./hardware-configuration.nix
    ../../modules/proxmox.nix
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

  networking.networkmanager.enable = true;
}
