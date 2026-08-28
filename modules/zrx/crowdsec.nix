{
  config,
  lib,
  ...
}: let
  cfg = config.zrx.crowdsec;
in {
  options.zrx.crowdsec = {
    enable = lib.mkEnableOption "Enable CrowdSec firewall bouncer";
  };

  config = lib.mkIf cfg.enable {
    networking.nftables.enable = true;

    services.crowdsec-firewall-bouncer = {
      enable = true;
      settings = {
        mode = "nftables";
        api_url = "http://127.0.0.1:8080/";
      };
      secrets.apiKeyPath = config.sops.secrets."crowdsec-firewall-bouncer-api-key".path;
    };
  };
}
