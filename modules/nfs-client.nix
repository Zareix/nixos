{
  fileSystems."/mnt/vulcain" = {
    device = "vulcain.home.local:/mnt/main/share";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];
  };
}
