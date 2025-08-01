{
  pkgs,
  lib,
  globals,
  secrets,
  ...
}: {
  system.stateVersion = "24.05";

  users.groups.${globals.username} = {
    name = globals.username;
    gid = 1000;
  };
  users.users.${globals.username} = {
    isNormalUser = true;
    description = globals.username;
    extraGroups = ["wheel" globals.username "render"];
    uid = 1000;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZwRQQJPlgMKHR2hGm2pI41xEu+Is9QSI966HV6i9uZ raphcatarino@gmail.com"
    ];
    shell = pkgs.zsh;
    hashedPassword = secrets.hashedPassword;
  };
  nix.settings.trusted-users = [globals.username];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  nixpkgs.config.allowUnfree = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 14d --keep 3";
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.firewall.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };
  security.sudo.wheelNeedsPassword = false;

  services.vscode-server.enable = true;

  environment.systemPackages = with pkgs; [
    alejandra
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
    git-crypt
    glib
    gnupg
    jq
    nano
    ncdu
    nettools
    nixfmt-classic
    openssh
    openssl
    rclone
    restic
    rustup
    starship
    unzip
    stow
    zoxide
    zsh

    (pkgs.python3.withPackages (python-pkgs: [python-pkgs.requests]))
  ];
  programs.zsh.enable = true;
  programs.tmux = {
    enable = true;
    clock24 = true;
  };

  nix.settings.download-buffer-size = 524288000;
}
