{ config, pkgs, ... }:
{
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "ens3"; # either ens3 (amd64) or enp1s0 (arm64)
    networkConfig.DHCP = "ipv4";
    routes = [ { routeConfig.Gateway = "fe80::1"; } ];
  };

  # for Iv6 only: add the following and replace this address with the one assigned to your instance
  # systemdP.network.networks."10-wan" = {
  #   address = [
  #     "2a01:4f8:aaaa:bbbb::1/64"
  #   ];
  # };
}
