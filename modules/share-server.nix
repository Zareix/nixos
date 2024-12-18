{
  globals,
  lib,
  config,
  ...
}:
let
  cfg = config.shareServer;
in
{
  options.shareServer = {
    shareFolder = lib.mkOption { type = lib.types.str; };
  };

  config = {
    # NFS
    services.nfs.server = {
      enable = true;
      statdPort = 4000;
      lockdPort = 4001;
      mountdPort = 4002;
      exports = ''
        ${cfg.shareFolder} *(rw,insecure,async,no_subtree_check,all_squash,anonuid=1000,anongid=1000,fsid=0)
      '';
    };

    # SAMBA
    services.samba = {
      enable = true;
      securityType = "user";
      shares = {
        share = {
          path = cfg.shareFolder;
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = globals.username;
          "force group" = globals.username;
        };
      };
    };
  };
}
