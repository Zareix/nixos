{
  config,
  pkgs,
  lib,
  dotfiles,
  ...
}:
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
        ${pkgs.stow}/bin/stow --adopt git nano fastfetch powerline10k zsh linux
      '';
    };

    stateVersion = nixos-release;
  };

  programs.git = {
    userName = "Zareix";
    userEmail = "raphcatarino@gmail.com";
  };

  programs.home-manager.enable = true;
}
