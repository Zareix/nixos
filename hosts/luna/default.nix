{modulesPath, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];

  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  console.keyMap = "fr";
}
