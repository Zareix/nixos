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
      default = pkgs.docker_28;
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

    system.activationScripts = {
      docker = {
        deps = ["docker"];
        text = ''
          echo "Restarting docker containers..."
          CONTAINERS="$(${cfg.dockerPkg}/bin/docker ps --format "{{.Names}}" | grep -E "(beszel|mhos|komodo)")"

          if [ -n "$CONTAINERS" ]; then
            echo "Found containers: $CONTAINERS"
            echo "$CONTAINERS" | while read -r container; do
              echo "Restarting container: $container"
              ${cfg.dockerPkg}/bin/docker restart "$container"
            done
          else
            echo "No matching containers found"
          fi
        '';
      };
    };
  };
}
