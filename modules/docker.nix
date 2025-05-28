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
}
