{ config, pkgs, lib, dotfiles, ... }:

{
  home = {
    username = "raphaelgc";
    homeDirectory = "/home/raphaelgc";

    file.dotfiles = {
      source = dotfiles;
      recursive = true;
      target = "./.tmp/dotfiles";
      onChange = ''
        rm -rf ./dotfiles
        cp -rL ./.tmp/dotfiles ./dotfiles
        rm -rf ./.tmp/dotfiles
        cd ./dotfiles
        ${pkgs.stow}/bin/stow --adopt git nano fastfetch starship zsh linux
      '';
    };
    
    stateVersion = "23.11";
  };

  programs.home-manager.enable = true;
}