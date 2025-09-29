{
  config,
  lib,
  ...
}: let
  cfg = config.zrx.nfsClient;
in {
  options.zrx.nfsClient = {
    enable = lib.mkEnableOption "NFS client and mount remote shares.";
    localOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Mount NFS shares only on local network.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/mnt/vulcain" = {
      # device = "vulcain.home.zrx.sh:/mnt/mass/share";
      device = "${
        if cfg.localOnly
        then "vulcain.home.zrx.sh"
        else "vulcain.zrx.sh"
      }:/mnt/mass/share";
      fsType = "nfs";
    };
  };
}
