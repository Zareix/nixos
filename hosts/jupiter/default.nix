{
  imports = [
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
}
