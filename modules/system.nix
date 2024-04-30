{
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  username = "raphaelgc";
in {
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  users.users.raphaelgc = {
    isNormalUser = true;
    description = "raphaelgc";
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZwRQQJPlgMKHR2hGm2pI41xEu+Is9QSI966HV6i9uZ raphcatarino@gmail.com"
    ];
    shell = pkgs.zsh;
  };
  nix.settings.trusted-users = [username];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };

  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 7d";
  };

  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";

  # networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    bat
    bun
    curl
    eza
    fastfetch
    fzf
    git
    git-crypt
    gnupg
    jq
    nano
    nettools
    python3
    rclone
    restic
    rustup
    starship
    unzip
    stow
    zoxide
    zsh

    (pkgs.python3.withPackages (python-pkgs: [
      python-pkgs.requests
    ]))
  ];
  programs.zsh.enable = true;
}