{
  config,
  pkgs,
  lib,
  globals,
  dotfiles,
  ...
}:
{
  programs.home-manager.enable = true;

  home = {
    username = globals.username;
    homeDirectory = "/home/${globals.username}";

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

    imports = [
      "${
        lib.fetchFromGitHub {
          owner = "msteen";
          repo = "nixos-vscode-server";
          rev = "master";
          hash = "sha256:fc900c16efc6a5ed972fb6be87df018bcf3035bc";
        }
      }/modules/vscode-server/home.nix"
    ];

    services.vscode-server.enable = true;

    stateVersion = "23.11";
  };

  programs.git = {
    userName = "Zareix";
    userEmail = "raphcatarino@gmail.com";
  };
}
