{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra
    age
    bat
    btop
    bun
    curl
    direnv
    eza
    fastfetch
    fzf
    gh
    git
    glib
    gnupg
    jq
    nano
    ncdu
    nettools
    nixd
    nixfmt-classic
    nixos-generators
    openssh
    openssl
    rclone
    restic
    rustup
    sops
    stow
    unzip
    zoxide
    zsh

    (pkgs.python3.withPackages (python-pkgs: [python-pkgs.requests]))
  ];

  programs.nix-ld.enable = true;
  programs.zsh.enable = true;
  programs.tmux = {
    enable = true;
    clock24 = true;
  };
}
