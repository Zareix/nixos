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

    system.userActivationScripts = {
      docker = {
        deps = ["docker"];
        text = ''
          echo "Restarting docker containers..." > /tmp/docker-restart.log
          CONTAINERS="$(${cfg.dockerPkg}/bin/docker ps --format "{{.Names}}" | grep -E "(beszel|komodo)")"

          if [ -n "$CONTAINERS" ]; then
            echo "$CONTAINERS" | while read -r container; do
              echo "Restarting container: $container" >> /tmp/docker-restart.log
              ${cfg.dockerPkg}/bin/docker restart "$container"
            done
          else
            echo "No matching containers found" >> /tmp/docker-restart.log
          fi
        '';
      };
    };
  };
}
