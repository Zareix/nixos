{config, ...}: let
  cfg = config.shareServer;
in {
  options.shareServer = {
    shareFolder = lib.mkOption {type = lib.types.str;};
  };

  config = {
    networking.firewall = {
      enable = true;

      eth0 = {
        allowedTCPPorts = [22];
        allowedUDPPortRanges = [];
      };

      tailscale0 = {
        allowedTCPPorts = [22];
        allowedUDPPortRanges = [];
      };
    };
  };
}
