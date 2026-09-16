{
  globals,
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.zrx.docker;
in {
  options.zrx.docker = {
    enable = lib.mkEnableOption "Docker and related services.";
    dockerPkg = lib.mkOption {
      type = lib.types.package;
      default = pkgs.docker_29;
      description = "Docker package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      package = cfg.dockerPkg;
      liveRestore = true;
      daemon.settings = {
        dns = ["100.100.100.100" "1.1.1.1"];
      };
    };

    users.users.${globals.username}.extraGroups = ["docker"];

    systemd.services.docker = {
      wants =
        ["network-online.target"]
        ++ lib.optional config.services.tailscale.enable "tailscaled.service";
      after = ["network-online.target" "tailscaled.service"];
    };

    systemd.services.docker-socket-refresh = {
      description = "Restart containers bind-mounting the Docker socket when it is recreated";
      wantedBy = ["multi-user.target"];
      after = ["docker.service"];
      partOf = ["docker.service" "docker.socket"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        docker=${cfg.dockerPkg}/bin/docker
        stamp=/run/docker-socket-inode

        ino=$(${pkgs.coreutils}/bin/stat -c %i /run/docker.sock 2>/dev/null || true)
        [ -n "$ino" ] || exit 0

        # premier passage (boot) : on mémorise, on ne touche à rien
        if [ ! -f "$stamp" ]; then echo "$ino" > "$stamp"; exit 0; fi
        # socket inchangé : rien à faire
        if [ "$(${pkgs.coreutils}/bin/cat "$stamp")" = "$ino" ]; then exit 0; fi
        echo "$ino" > "$stamp"

        targets=""
        for id in $($docker ps -q); do
          if $docker inspect -f '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' "$id" \
              | ${pkgs.gnugrep}/bin/grep -qxE '/run|/var/run|/run/docker\.sock|/var/run/docker\.sock'; then
            targets="$targets $($docker inspect -f '{{.Name}}' "$id")"
          fi
        done
        if [ -n "$targets" ]; then
          echo "socket docker recréé -> restart de:$targets"
          $docker restart $targets
        fi
      '';
    };
  };
}
