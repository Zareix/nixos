{ pkgs, lib, ... }:
{
  users.users.raphaelgc.extraGroups = [ "docker" ];

  virtualisation.docker.enable = true;

  home-manager.users.raphaelgc.home.file.dockerConfig = {
    source = ../secrets/docker.json;
    target = ".docker/config.json";
    onChange = ''
      cp  .docker/config.json .docker/config.json.tmp
      rm -f .docker/config.json
      mv .docker/config.json.tmp .docker/config.json
    '';
  };
}
