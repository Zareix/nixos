{ pkgs, ... }:{
  environment.systemPackages = with pkgs; config.environment.systemPackages ++ [
    tailscale
  ];

  services.tailscale.enable = true;
}