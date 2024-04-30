{
  pkgs,
  lib,
  ...
}:{
  users.users.raphaelgc.extraGroups = [ "docker" ];

  virtualisation.docker.enable = true;
}