{modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal-combined.nix")
    ../../modules/home-manager.nix
    ../../modules/system.nix
    ../../modules/docker.nix
    ../../modules/tailscale.nix
    ../../modules/nfs-client.nix
  ];

  networking.hostName = "luna";
}
