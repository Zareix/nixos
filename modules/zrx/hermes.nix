{
  config,
  lib,
  pkgs,
  globals,
  ...
}: let
  cfg = config.zrx.hermes-agent;
in {
  options.zrx.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent service.";
  };

  config = lib.mkIf cfg.enable {
    services.hermes-agent = {
      enable = true;
      container.enable = true;
      settings = {
        model.default = "opencode-go/deepseek-v4-flash";
      };
      environmentFiles = [config.sops.secrets."hermes-env".path];
      container.hostUsers = [globals.username];
      addToSystemPackages = true;
    };

    environment.systemPackages = with pkgs; [
      signal-cli
    ];
  };
}
