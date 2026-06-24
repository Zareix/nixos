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
    packages = with pkgs; [
      docker-buildx
    ];
    file.".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";

    stateVersion = "23.11";
  };
}
