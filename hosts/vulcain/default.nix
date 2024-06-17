{ config, pkgs, ... }:

{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    (import ../../modules/share-server.nix { shareFolder = "/mnt/main/share"; })
  ];

  networking.hostName = "vulcain";
}
