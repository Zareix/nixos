# Patch:
# 1. use module.nix directly from https://github.com/Zareix/gitwatch/tree/fix/nix-args-quote
#    which fixes argument quoting for -r, -m, -b flags.
# 2. Uses pkgs-unstable.gitwatch (v0.5) via nixpkgs.overlays since the fork's module.nix
#    references ./gitwatch.nix locally (replaced by the overlay).
# TODO: remove this patch once the PR is merged into nixpkgs-stable.
{
  pkgs-unstable,
  gitwatch-fork,
  ...
}: {
  disabledModules = ["services/monitoring/gitwatch.nix"];

  imports = ["${gitwatch-fork}/module.nix"];

  nixpkgs.overlays = [
    (_final: _prev: {
      gitwatch = pkgs-unstable.gitwatch;
    })
  ];
}
