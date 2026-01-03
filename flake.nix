{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    dotfiles = {
      url = "github:Zareix/dotfiles";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    ...
  }: let
    globals = import ./vars.nix;
    secrets = import ./secrets/vars.nix;

    hosts = [
      {
        name = "default";
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
              hostname = host.name;
            };
          };
          modules = [
            ./modules/common.nix
            inputs.home-manager.nixosModules.home-manager
            ./modules/home-manager.nix
            ./hosts/${host.name}
            {
              home-manager.extraSpecialArgs = specialArgs;
            }
          ];
        };
      })
      hosts);
  };
}
