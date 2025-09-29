{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/nfs-client.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    nfsClient = {
      enable = true;
      localOnly = true;
    };
  };
}
