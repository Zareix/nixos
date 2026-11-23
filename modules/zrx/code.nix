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
in {
  options.zrx.code = {
    enable = lib.mkEnableOption "OpenCode AI coding agent configuration.";

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

    context = lib.mkOption {
      type = lib.types.either lib.types.lines lib.types.path;
      default = ../../home/agents/AGENTS.md;
      description = "Global agent instructions written to ~/${agentsRelPath}.";
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

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.username} = {
      home.file.${agentsRelPath} =
        if lib.isPath cfg.context
        then {source = cfg.context;}
        else lib.mkIf (cfg.context != "") {text = cfg.context;};

      programs.opencode = {
        enable = true;
        package = cfg.package;
        extraPackages = cfg.extraPackages;
        settings =
          {
            autoupdate = false;
          }
          // cfg.settings
          // {
            instructions =
              lib.optional (lib.isPath cfg.context || cfg.context != "") "~/${agentsRelPath}"
              ++ (cfg.settings.instructions or []);
          };
        tui = cfg.tui;
      };
    };
  };
}
