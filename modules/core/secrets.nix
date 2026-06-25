{globals, ...}: {
  sops.secrets.hashedPassword = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
  };

  sops.secrets.docker_config = {
    sopsFile = ../../secrets/home.yaml;
    path = "/home/${globals.username}/.docker/config.json";
    owner = globals.username;
    mode = "0600";
  };
  sops.secrets.zshenv = {
    sopsFile = ../../secrets/home.yaml;
    path = "/home/${globals.username}/.zshenv";
    owner = globals.username;
    mode = "0600";
  };
  sops.secrets.rclone_conf = {
    sopsFile = ../../secrets/home.yaml;
    path = "/home/${globals.username}/.config/rclone/rclone.conf";
    owner = globals.username;
    mode = "0600";
  };
}
