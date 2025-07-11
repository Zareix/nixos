{
  globals,
  pkgs,
  ...
}: let
  dockerPkg = pkgs.docker_28;
in {
  virtualisation.docker.enable = true;
  virtualisation.docker.package = dockerPkg;

  users.users.${globals.username}.extraGroups = ["docker"];

  services.gitwatch.docker-stacks = {
    enable = true;
    path = "/data/stacks";
    remote = "https://github.com/Zareix/docker.git";
    user = "raphaelgc";
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      "30 9 * * * root echo \"$(date): Starting docker prune\" >> /tmp/cron_docker-prune.log && ${dockerPkg}/bin/docker system prune -af >> /tmp/cron_docker-prune.log 2>&1"
    ];
  };

  system.activationScripts = {
    docker = {
      deps = ["docker"];
      text = ''
        echo "Restarting docker containers..."
        CONTAINERS="$(${dockerPkg}/bin/docker ps --format "{{.Names}}" | grep -E "(beszel|mhos|komodo)")"

        if [ -n "$CONTAINERS" ]; then
          echo "Found containers: $CONTAINERS"
          echo "$CONTAINERS" | while read -r container; do
            echo "Restarting container: $container"
            ${dockerPkg}/bin/docker restart "$container"
          done
        else
          echo "No matching containers found"
        fi
      '';
    };
  };
}
