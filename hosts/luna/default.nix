{...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    dyndns.enable = true;
  };


  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };
  console.keyMap = "fr";

  networking.networkmanager.enable = true;

  system.stateVersion = "24.05";
}
