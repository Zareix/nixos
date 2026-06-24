{globals, ...}: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "ha-bak";
  home-manager.users = {
    ${globals.username} = {
      imports = [
        ../home
        ../home/${globals.username}.nix
      ];
    };
    root = {
      imports = [
        ../home
        ../home/root.nix
      ];
    };
  };
}
