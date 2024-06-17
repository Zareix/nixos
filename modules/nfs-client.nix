{
  fileSystems."/mnt/vulcain" = {
    device = "vulcain.home.ts:/mnt/main/share";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];
  };
}
