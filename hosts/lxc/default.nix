{
  config,
  pkgs,
  nixos-release,
  ...
}:

{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/nfs-client.nix
  ];

  system.stateVersion = nixos-release;
}
