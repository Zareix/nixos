{
  pkgs,
  inputs,
  config,
  ...
}: {
  programs.home-manager.enable = true;

  imports = [inputs.dotfiles.homeManagerModules.default];

  dotfiles = {
    enable = true;
    packages = ["git" "nano" "fastfetch" "powerlevel10k" "zsh" "linux"];
  };

  sops = {
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    secrets = {
      docker_config = {
        sopsFile = ../secrets/home.yaml;
        path = "${config.home.homeDirectory}/.docker/config.json";
      };
      zshenv = {
        sopsFile = ../secrets/home.yaml;
        path = "${config.home.homeDirectory}/.zshenv";
      };
      rclone_conf = {
        sopsFile = ../secrets/home.yaml;
        path = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
      };
    };
  };

  home = {
    packages = with pkgs; [
      docker-buildx
    ];
    file.".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";

    stateVersion = "23.11";
  };
}
