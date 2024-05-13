{ pkgs, ... }:{
  services.tailscale.enable = true;

  services.tailscale.extraUpFlags = [
    "--stateful-filtering=false"
  ];
}