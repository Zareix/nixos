{
  pkgs,
  inputs,
  ...
}: {
  programs.home-manager.enable = true;

  home = {
    file.dotfiles = {
      source = inputs.dotfiles;
      recursive = true;
      target = "./.tmp/dotfiles";
      onChange = ''
        rm -rf ./dotfiles
        cp -rL ./.tmp/dotfiles ./dotfiles
        rm -rf ./.tmp/dotfiles
        cd ./dotfiles
        ${pkgs.stow}/bin/stow --adopt git nano fastfetch powerline10k zsh linux
      '';
    };
    # TODO Remove stow and onChange that to use home-manager file only like so
    # file.dotfiles-test = {
    #   source = inputs.dotfiles + "/fastfetch";
    #   recursive = true;
    #   target = "./test";
    # };

    file.dockerConfig = {
      source = ../secrets/docker.json;
      target = "./.tmp/.docker/config.json";
      onChange = ''
        mkdir -p ./.docker
        rm -rf ./.docker/config.json
        cp -rL ./.tmp/.docker/config.json ./.docker/config.json
        rm -rf ./.tmp/.docker/config.json
      '';
    };

    file.zshenv = {
      source = ../secrets/.zshenv;
      target = ".zshenv";
    };

    file.rcloneConfig = {
      source = ../secrets/rclone.conf;
      target = ".config/rclone/rclone.conf";
    };

    stateVersion = "23.11";
  };
}
