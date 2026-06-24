{
  pkgs,
  config,
  globals,
  ...
}: {
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
    hashedPasswordFile = config.sops.secrets.hashedPassword.path;
  };

  security.sudo.wheelNeedsPassword = false;
}
