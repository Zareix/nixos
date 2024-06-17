{ config, pkgs, ... }:

{
  imports = [
    ../../modules/proxmox.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/share-server.nix
  ];

  shareServer.shareFolder = "/mnt/main/share";

  networking.hostName = "vulcain";
}
