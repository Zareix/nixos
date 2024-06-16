{
  fileSystems."/mnt/vulcain" = {
    device = "vulcain.home.local:/";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };
}
