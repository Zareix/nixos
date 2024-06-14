{ config, pkgs, ... }:

{
  imports = [
    path:./hardware-configuration.nix
    path:./networking.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];
}
