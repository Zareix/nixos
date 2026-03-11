# Patch:
# 1. use module.nix directly from https://github.com/gitwatch/gitwatch
#    which also include fixes for argument quoting.
# 2. Uses pkgs-unstable.gitwatch (v0.5) via nixpkgs.overlays since the fork's module.nix
#    references ./gitwatch.nix locally.
{
  pkgs-unstable,
  gitwatch,
  ...
}: {
  disabledModules = ["services/monitoring/gitwatch.nix"];

  imports = ["${gitwatch}/module.nix"];

  nixpkgs.overlays = [
    (_final: _prev: {
      gitwatch = pkgs-unstable.gitwatch;
    })
  ];
}
