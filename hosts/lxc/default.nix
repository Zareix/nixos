{ config, pkgs, ... }:

{
  imports =
    [
      ../../modules/system.nix
      ../../modules/docker.nix
      ../../modules/tailscale.nix
      ../../modules/nfs-client.nix
    ];

  networking.hostName = "lxc";

  system.stateVersion = "23.11";
}

