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
    };

    systemd.services.docker.serviceConfig = {
      ExecStartPost = [
        "-${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker ps -aq --filter \"name=komodo\" | ${pkgs.findutils}/bin/xargs -r ${pkgs.docker}/bin/docker restart'"
        "-${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker ps -aq --filter \"name=godoxy\" | ${pkgs.findutils}/bin/xargs -r ${pkgs.docker}/bin/docker restart'"
      ];
    };
  };
}
