{ config, pkgs, ... }:

{
  imports = [
    /etc/nixos/hosts/uranus/hardware-configuration.nix
    /etc/nixos/hosts/uranus/networking.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];
}
