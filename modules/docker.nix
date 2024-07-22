{ globals, pkgs, ... }: {
  users.users.${globals.username}.extraGroups = [ "docker" ];

  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_27;

  home-manager.users.${globals.username}.home.file.dockerConfig = {
    source = ../secrets/docker.json;
    target = "./.tmp/.docker/config.json";
    onChange = ''
      mkdir -p ./.docker
      rm -rf ./.docker/config.json
      cp -rL ./.tmp/.docker/config.json ./.docker/config.json
      rm -rf ./.tmp/.docker/config.json
    '';
  };
}
