{ pkgs-unstable, ... }: {
  services.tailscale.enable = true;
  services.tailscale.package = pkgs-unstable.tailscale;
  services.tailscale.extraUpFlags = [ "--stateful-filtering=false" ];

  services.resolved = {
    extraConfig = ''
      DNSStubListener=no
    '';
  };
}
