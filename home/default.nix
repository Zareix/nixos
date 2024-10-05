{
  config,
  pkgs,
  lib,
  dotfiles,
  username,
  ...
}:
{
  programs.home-manager.enable = true;

  home = {
    username = username;
    homeDirectory = username == "root" ? "/root" : "/home/${username}";

    file.dotfiles = {
      source = dotfiles;
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
