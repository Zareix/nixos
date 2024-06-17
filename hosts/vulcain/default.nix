{ config, pkgs, ... }:

{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/share-server.nix
  ];

  networking.hostName = "vulcain";
  shareServer.shareFolder = "/mnt/main/share";
}
