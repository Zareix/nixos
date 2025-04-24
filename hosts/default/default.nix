{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/home-manager.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    # ../../modules/tailscale.nix
    # ../../modules/nfs-client.nix
  ];

  networking.hostName = "nixos";
}
