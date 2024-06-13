{ config, pkgs, ... }:

{
  imports = [
    ../../modules/hetzner.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];

  systemdP.network.networks."10-wan" = {
    address = [ "2a01:4f8:c013:4993::/64" ];
  };

  system.stateVersion = "24.05";
}
