{
  pkgs,
  pkgs-unstable,
  globals,
  config,
  lib,
  ...
}: let
  cfg = config.zrx.code;
  jsonFormat = pkgs.formats.json {};
  agentsRelPath = ".agents/AGENTS.md";
  hasContext = lib.isPath cfg.context || cfg.context != "";
in {
  options.zrx.code = {
    enable = lib.mkEnableOption "AI coding agents configuration (OpenCode & Antigravity CLI).";

    context = lib.mkOption {
      type = lib.types.either lib.types.lines lib.types.path;
      default = ../../home/agents/AGENTS.md;
      description = "Global agent instructions written to ~/${agentsRelPath} and shared with configured coding agents.";
    };

    opencode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable OpenCode.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs-unstable.opencode;
        description = "OpenCode package to install.";
      };

      extraPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Extra packages made available on OpenCode's PATH.";
      };

      settings = lib.mkOption {
        type = jsonFormat.type;
        default = {};
        description = "Additional OpenCode settings written to ~/.config/opencode/opencode.json.";
      };

      tui = lib.mkOption {
        type = jsonFormat.type;
        default = {};
        description = "OpenCode TUI configuration written to ~/.config/opencode/tui.json.";
      };
    };

    antigravity = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Antigravity CLI (agy).";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs-unstable.antigravity-cli;
        description = "Antigravity CLI package to install.";
      };

      settings = lib.mkOption {
        type = jsonFormat.type;
        default = {};
        description = "Antigravity CLI settings written to ~/.gemini/antigravity-cli/settings.json.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.username} = {
      home.file.${agentsRelPath} = lib.mkIf hasContext (
        if lib.isPath cfg.context
        then {source = cfg.context;}
        else {text = cfg.context;}
      );

      programs.opencode = lib.mkIf cfg.opencode.enable {
        enable = true;
        package = cfg.opencode.package;
        extraPackages = cfg.opencode.extraPackages;
        settings =
          {
            autoupdate = false;
          }
          // cfg.opencode.settings
          // {
            instructions =
              lib.optional hasContext "~/${agentsRelPath}"
              ++ (cfg.opencode.settings.instructions or []);
          };
        tui = cfg.opencode.tui;
      };

      programs.antigravity-cli = lib.mkIf cfg.antigravity.enable {
        enable = true;
        package = cfg.antigravity.package;
        settings = cfg.antigravity.settings;
        context = lib.optionalAttrs hasContext {
          AGENTS = cfg.context;
        };
      };
    };
  };
}
