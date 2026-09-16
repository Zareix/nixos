{
  globals,
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.zrx.docker;
in {
  options.zrx.docker = {
    enable = lib.mkEnableOption "Docker and related services.";
    dockerPkg = lib.mkOption {
      type = lib.types.package;
      default = pkgs.docker_29;
      description = "Docker package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      package = cfg.dockerPkg;
      liveRestore = true;
      daemon.settings = {
        dns = ["100.100.100.100" "1.1.1.1"];
      };
    };

    users.users.${globals.username}.extraGroups = ["docker"];

    systemd.services.docker = {
      wants =
        ["network-online.target"]
        ++ lib.optional config.services.tailscale.enable "tailscaled.service";
      after = ["network-online.target" "tailscaled.service"];
    };
  };
}
