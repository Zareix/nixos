{
  globals,
  pkgs,
  ...
}: {
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_27;

  users.users.${globals.username}.extraGroups = ["docker"];

  services.gitwatch.docker-stacks = {
    enable = true;
    path = "/data/stacks";
    remote = "https://github.com/Zareix/docker.git";
    user = "[Gitwatch] Zareix";
  };
}
