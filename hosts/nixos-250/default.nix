{ config, pkgs, ... }:

{
  imports =
    [
      ../../modules/system.nix
      ../../modules/docker.nix
      ../../modules/tailscale.nix
    ];

  networking.hostName = "nixos-250";

  system.stateVersion = "23.11";
}

