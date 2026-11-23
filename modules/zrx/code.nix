{
  pkgs,
  pkgs-unstable,
  globals,
  config,
  lib,
  ...
}: let
  cfg = config.zrx.code;
  agentsMd = ../../home/agents/AGENTS.md;
  t3codePkg = pkgs-unstable.t3code.override {
    enableCodex = false;
    enableOpencode = true;
  };
in {
  options.zrx.code = {
    enable = lib.mkEnableOption "AI coding agents (OpenCode, Antigravity CLI, T3 Code).";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.nodejs];

    users.users.${globals.username}.linger = true;

    sops.secrets.opencode_go_api_key = {
      sopsFile = ../../secrets/home.yaml;
      owner = globals.username;
      mode = "0400";
    };

    home-manager.users.${globals.username} = {
      home.file.".agents/AGENTS.md".source = agentsMd;

      programs.opencode = {
        enable = true;
        package = pkgs-unstable.opencode;
        settings = {
          autoupdate = false;
          instructions = ["~/.agents/AGENTS.md"];
          providers."opencode-go".settings.apiKey = "{file:${config.sops.secrets.opencode_go_api_key.path}}";
        };
      };

      programs.antigravity-cli = {
        enable = true;
        package = pkgs-unstable.antigravity-cli;
        context.AGENTS = agentsMd;
      };

      programs.t3code = {
        enable = true;
        package = t3codePkg;
      };

      systemd.user.services.t3code = {
        Unit = {
          Description = "T3 Code server";
          After = ["network-online.target"];
        };
        Service = {
          ExecStart = "${t3codePkg}/bin/t3 serve --lan";
          WorkingDirectory = "%h";
          Environment = [
            "PATH=/etc/profiles/per-user/${globals.username}/bin:/run/current-system/sw/bin:/usr/bin:/bin"
          ];
          EnvironmentFile = "-%h/.t3/service.env";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = ["default.target"];
      };
    };
  };
}
