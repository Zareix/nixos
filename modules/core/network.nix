{meta, ...}: {
  networking.firewall.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  networking.hostName =
    if meta.hostname == "default"
    then "nixos"
    else meta.hostname;
}
