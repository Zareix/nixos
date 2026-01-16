{
  imports = [
    ../../modules/proxmox.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    # nfsClient = {
    #   enable = true;
    #   local = true;
    # };
    shareServer = {
      enable = true;
      shareFolder = "/mnt/mass/share";
    };
  };
}
