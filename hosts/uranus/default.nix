{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];
}
