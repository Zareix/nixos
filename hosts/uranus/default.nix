{ config, pkgs, ... }:

{
  imports = [
    "path:/etc/nixos/hosts/uranus/hardware-configuration.nix"
    "path:/etc/nixos/hosts/uranus/networking.nix"
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];
}
