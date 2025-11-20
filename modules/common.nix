{
  pkgs,
  lib,
  globals,
  secrets,
  meta,
  ...
}: {
  system.stateVersion = "24.05";

  imports = lib.filesystem.listFilesRecursive ./zrx;

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

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.hostName =
    if meta.hostname == "default"
    then "nixos"
    else meta.hostname;
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
    nixd
    nixfmt-classic
    nixos-generators
    openssh
    openssl
    rclone
    restic
    rustup
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

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 14d --keep 3";
  };

  nix.settings.download-buffer-size = 524288000;
}
