{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    dotfiles.url = "github:Zareix/dotfiles";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    ...
  }: let
    globals = import ./vars.nix;

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
    ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (host: {
        name = host.name;
        value = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs globals;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            meta = {
              hostname = host.name;
            };
          };
          modules = [
            inputs.sops-nix.nixosModules.sops
            ./modules/common.nix
            inputs.home-manager.nixosModules.home-manager
            ./modules/home-manager.nix
            {
              home-manager.extraSpecialArgs = specialArgs;
            }
            ./hosts/${host.name}
          ];
        };
      })
      hosts);
  };
}
