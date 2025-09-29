{
  imports = [
    ../../modules/proxmox.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = false;
    nfsClient.enable = false;
  };
}
