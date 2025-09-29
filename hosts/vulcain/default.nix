{pkgs, ...}: {
  imports = [
    ../../modules/proxmox.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
  ];

  shareServer = {
    enable = true;
    shareFolder = "/mnt/mass/share";
  };

  environment.systemPackages = with pkgs; [
    libva-utils
  ];
  hardware.graphics.enable = true;
}
