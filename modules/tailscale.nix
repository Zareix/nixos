{ pkgs, ... }:{
  environment.systemPackages = with pkgs; environment.systemPackages ++ [
    tailscale
  ];

  services.tailscale.enable = true;
}