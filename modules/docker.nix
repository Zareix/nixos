{
  globals,
  pkgs,
  ...
}: {
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_27;

  users.users.${globals.username}.extraGroups = ["docker"];
}
