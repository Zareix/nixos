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
    virtualisation.docker.enable = true;
    virtualisation.docker.package = cfg.dockerPkg;

    users.users.${globals.username}.extraGroups = ["docker"];

    services.gitwatch.docker-stacks = {
      enable = true;
      path = "/data/stacks";
      remote = "https://github.com/Zareix/docker.git";
      user = "raphaelgc";
      message = "chore: auto-commit by gitwatch";
    };

    systemd.services.docker.serviceConfig = {
      ExecStartPost = [
        "-${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker ps -q --filter volume=/var/run/docker.sock --filter volume=/run/docker.sock | ${pkgs.findutils}/bin/xargs -r ${pkgs.docker}/bin/docker restart'"
      ];
    };
  };
}
