{
  fileSystems."/mnt/vulcain" = {
    device = "vulcain.home.zrx.sh:/mnt/main/share";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];
  };
}
