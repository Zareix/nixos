{...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    dyndns.enable = true;
    crowdsec.enable = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Auto-reboot if kernel panics or the system hangs headlessly
  boot.kernelParams = [
    "panic=10"
    "oops=panic"
  ];
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10s";
  };

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };
  console.keyMap = "fr";

  networking.networkmanager.enable = true;

  system.stateVersion = "24.05";
}
