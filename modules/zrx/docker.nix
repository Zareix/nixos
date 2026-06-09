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
    };

    users.users.${globals.username}.extraGroups = ["docker"];
  };
}
