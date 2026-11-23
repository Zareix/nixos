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
in {
  options.zrx.code = {
    enable = lib.mkEnableOption "AI coding agents (OpenCode, Antigravity CLI) and T3 Code prerequisites.";
  };

  config = lib.mkIf cfg.enable {
    environment.localBinInPath = true;
    environment.variables.T3CODE_CLOUDFLARED_PATH = "${pkgs.cloudflared}/bin/cloudflared";
    environment.systemPackages = [
      pkgs.nodejs
      pkgs.cloudflared
    ];

    users.users.${globals.username}.linger = true;

    systemd.user.extraConfig = ''
      DefaultEnvironment="T3CODE_CLOUDFLARED_PATH=${pkgs.cloudflared}/bin/cloudflared"
    '';

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
    };
  };
}
