{pkgs, ...}: {
  imports = [
    pkgs.modules.installer.cd-dvd.installation-cd-minimal-combined
    ../../modules/home-manager.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/nfs-client.nix
  ];

  networking.hostName = "luna";
}
