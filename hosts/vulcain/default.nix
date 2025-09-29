{pkgs, ...}: {
  imports = [
    ../../modules/proxmox.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/share-server.nix
  ];

  shareServer.shareFolder = "/mnt/mass/share";

  environment.systemPackages = with pkgs; [
    libva-utils
  ];
  hardware.graphics.enable = true;
}
