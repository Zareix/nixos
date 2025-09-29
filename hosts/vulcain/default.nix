{pkgs, ...}: {
  imports = [
    ../../modules/proxmox.nix
  ];

  zrx = {
    docker.enable = true;
    tailscale.enable = true;
    shareServer = {
      enable = true;
      shareFolder = "/mnt/mass/share";
    };
  };

  environment.systemPackages = with pkgs; [
    libva-utils
  ];
  hardware.graphics.enable = true;
}
