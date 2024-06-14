{ config, pkgs, ... }:

{
  imports = [
    ../../modules/hetzner.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];
}
