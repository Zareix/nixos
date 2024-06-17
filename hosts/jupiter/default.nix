{ config, pkgs, ... }:

{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/nfs-client.nix
  ];

  networking.hostName = "jupiter";
}
