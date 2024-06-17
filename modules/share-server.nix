{ globals, ... }:
{
  # NFS
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /mnt/main/share         *(rw,insecure,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,fsid=0)
  '';

  # SAMBA
  services.samba = {
    enable = true;
    securityType = "user";
    # openFirewall = true;
    shares = {
      public = {
        path = "/mnt/main/share";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = globals.username;
        "force group" = globals.username;
      };
    };
  };
}
