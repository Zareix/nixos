{
  imports = [
    ../../modules/proxmox.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    nfsClient = {
      enable = true;
      local = true;
    };
  };
}
