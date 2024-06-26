{ pkgs, lib, ... }:
{
  # This line needs to be updated with th value of "/data/coolify/ssh/keys/id.root@host.docker.internal.pub"
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2T0IuLyI6x7wiOeMtrl41cw+4HuA6QQwQe86FP4Tl7 root@coolify"
  ];

  systemd.services.coolify-prepare-files = {
    description = "Setup files for coolify";
    wantedBy = [ "coolify.service" ];
    wants = [ "data-coolify.mount" ];
    script = ''
      #! ${pkgs.bash}/bin/bash
      NAMES='source ssh applications databases backups services proxy webhooks-during-maintenance ssh/keys ssh/mux proxy/dynamic'
      for NAME in $NAMES
      do
        FOLDER_PATH="/data/coolify/$NAME"
        if [ ! -d "$FOLDER_PATH" ]; then
          mkdir -p "$FOLDER_PATH"
        fi
      done

      if [ ! -f "/data/coolify/source/docker-compose.yml" ]; then
        ${pkgs.curl}/bin/curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml -o /data/coolify/source/docker-compose.yml
        ${pkgs.curl}/bin/curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml -o /data/coolify/source/docker-compose.prod.yml
        ${pkgs.curl}/bin/curl -fsSL https://cdn.coollabs.io/coolify/.env.production -o /data/coolify/source/.env
        ${pkgs.curl}/bin/curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh -o /data/coolify/source/upgrade.sh
      fi

      # Generate SSH key if not ready
      if [ ! -f "/data/coolify/ssh/keys/id.root@host.docker.internal" ]; then
        ${pkgs.openssh}/bin/ssh-keygen -f /data/coolify/ssh/keys/id.root@host.docker.internal -t ed25519 -N "" -C root@coolify
      fi

      chown -R 9999:root /data/coolify
      chmod -R 700 /data/coolify

      if ! grep -q DONE=true /data/coolify/source/.env ; then
        sed -i "s|APP_ID=.*|APP_ID=$(${pkgs.openssl}/bin/openssl rand -hex 16)|g" /data/coolify/source/.env
        sed -i "s|APP_KEY=.*|APP_KEY=base64:$(${pkgs.openssl}/bin/openssl rand -base64 32)|g" /data/coolify/source/.env
        sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 32)|g" /data/coolify/source/.env
        sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 32)|g" /data/coolify/source/.env
        sed -i "s|PUSHER_APP_ID=.*|PUSHER_APP_ID=$(${pkgs.openssl}/bin/openssl rand -hex 32)|g" /data/coolify/source/.env
        sed -i "s|PUSHER_APP_KEY=.*|PUSHER_APP_KEY=$(${pkgs.openssl}/bin/openssl rand -hex 32)|g" /data/coolify/source/.env
        sed -i "s|PUSHER_APP_SECRET=.*|PUSHER_APP_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)|g" /data/coolify/source/.env
        echo "DONE=true" >> /data/coolify/source/.env
      fi
    '';
  };
  systemd.services.coolify = {
    script = ''
      "${pkgs.docker}/bin/docker" network create --attachable coolify
      "${pkgs.docker}/bin/docker" compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d --pull always --remove-orphans --force-recreate
    '';
    after = [
      "docker.service"
      "docker.socket"
    ];
    wantedBy = [ "multi-user.target" ];
  };
}
