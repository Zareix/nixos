{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    gitwatch.url = "github:gitwatch/gitwatch";

    dotfiles = {
      url = "github:Zareix/dotfiles";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    vscode-server,
    ...
  }: let
    globals = import ./vars.nix;
    secrets = import ./secrets/vars.nix;

    hosts = [
      {
        name = "default";
        hostname = "nixos";
      }
      {
        name = "luna";
      }
      {
        name = "jupiter";
      }
      {
        name = "vulcain";
      }
    ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (host: {
        name = host.name;
        value = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs globals secrets;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            meta = {
              hostname = host.hostname or host.name;
            };
          };
          modules = [
            ./modules/common.nix
            ./modules/share-server.nix
            ./modules/home-manager.nix
            ./hosts/${host.name}
            home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = specialArgs;
            }
            vscode-server.nixosModules.default
          ];
        };
      })
      hosts);
  };
}
