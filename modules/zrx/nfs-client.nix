{
  config,
  lib,
  ...
}: let
  cfg = config.zrx.nfsClient;
in {
  options.zrx.nfsClient = {
    enable = lib.mkEnableOption "NFS client and mount remote shares.";
    local = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Mount NFS shares on local network.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/mnt/vulcain" = {
      device = "${
        if cfg.local
        then "vulcain.home.zrx.sh"
        else "vulcain.zrx.sh"
      }:/mnt/mass/share";
      fsType = "nfs";
      options = [
        "vers=3"
        "proto=tcp"
	"rw"
        "hard"
	"nolock"
	"noatime"
        "rsize=262144"
        "wsize=262144"
        "_netdev"
        "nofail"
      ];
    };
  };
}
