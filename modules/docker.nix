{ pkgs, lib, ... }:
{
  users.users.raphaelgc.extraGroups = [ "docker" ];

  virtualisation.docker.enable = true;

  home-manager.users.raphaelgc.home.file.dockerConfig = {
    source = ../secrets/docker.json;
    target = ".docker/config.json";
  };
}
