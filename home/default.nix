{
  pkgs,
  inputs,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [inputs.dotfiles.homeManagerModules.default];

  dotfiles = {
    enable = true;
    packages = ["git" "nano" "fastfetch" "powerlevel10k" "zsh" "linux"];
  };

  home = {
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
    packages = with pkgs; [
      docker-buildx
    ];
    file.".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";

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
