{
  pkgs,
  globals,
  config,
  lib,
  ...
}: let
  cfg = config.zrx.dyndns;
in {
  options.zrx.dyndns = {
    enable = lib.mkEnableOption "Dynamic DNS updater service.";
  };

  config = lib.mkIf cfg.enable {
    systemd.timers."dynamic-dns" = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "dynamic-dns.service";
      };
    };

    systemd.services."dynamic-dns" = {
      script = ''
        set -eu

        source ~/.zshenv
        ${pkgs.git}/bin/git clone https://Zareix:$GITHUB_TOKEN@github.com/Zareix/terraform.git /tmp/dynamic_dns || \
          ${pkgs.git}/bin/git -C /tmp/dynamic_dns pull
        cd /tmp/dynamic_dns || exit 1

        STORED_IP=$(grep -Po '^reverse_proxy_public_ip *= *"\K[^"]*' terraform.tfvars)
        NEW_IP=$(${pkgs.curl}/bin/curl -s https://api.ipify.org?format=json | grep -Po '"ip"\s*:\s*"\K[^"]*')

        if [ "$STORED_IP" != "$NEW_IP" ]; then
            echo "IP address changed from $STORED_IP to $NEW_IP. Updating..."
            sed -i.bak -E "s/^(reverse_proxy_public_ip *= *\").*(\")/\1$NEW_IP\2/" terraform.tfvars
            ${pkgs.git}/bin/git add terraform.tfvars
            ${pkgs.git}/bin/git commit -m "chore: Update reverse proxy public IP"
            ${pkgs.git}/bin/git push
        else
            echo "IP address unchanged. No update needed."
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        User = globals.username;
      };
    };
  };
}
