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
  in {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
          ./hosts/default
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = specialArgs;
          }
          vscode-server.nixosModules.default
        ];
      };
      luna = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
          <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal-combined.nix>
          ./hosts/luna
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = specialArgs;
          }
          vscode-server.nixosModules.default
        ];
      };
      jupiter = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
          ./hosts/jupiter
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = specialArgs;
          }
          vscode-server.nixosModules.default
        ];
      };
      vulcain = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
          ./hosts/vulcain
          home-manager.nixosModules.home-manager
          {
            home-manager.extraSpecialArgs = specialArgs;
          }
          vscode-server.nixosModules.default
        ];
      };
    };
  };
}
