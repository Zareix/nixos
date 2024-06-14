{ config, pkgs, ... }:

{
  imports = [
    (builtins.toFile "/etc/nixos/hosts/uranus/hardware-configuration.nix")
    (builtins.toFile "/etc/nixos/hosts/uranus/networking.nix")
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];
}
