{ config, pkgs, ... }:

{
  imports =
    [
      ../../modules/system.nix
      ../../modules/docker.nix
      ../../modules/tailscale.nix
      ../../modules/nfs-client.nix
    ];

  system.stateVersion = "23.11";
}

