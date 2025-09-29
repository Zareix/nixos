{
  pkgs-unstable,
  lib,
  config,
  ...
}
: let
  cfg = config.zrx.tailscale;
in {
  options.zrx.tailscale = {
    enable = lib.mkEnableOption "Tailscale client.";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;
    services.tailscale.package = pkgs-unstable.tailscale;

    services.tailscale.extraUpFlags = ["--stateful-filtering=false"];
    services.tailscale.openFirewall = true;
    services.resolved = {
      extraConfig = ''
        DNSStubListener=no
      '';
    };
  };
}
