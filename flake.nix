{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
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
    gitwatch,
    ...
  }: let
    inherit (self) outputs;
    globals = import ./vars.nix;
    secrets = import ./secrets/vars.nix;
  in {
    nixosConfigurations = {
      default = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            outputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules =
          [
            ./hosts/default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "ha-bak";
              home-manager.extraSpecialArgs =
                inputs
                // {
                  inherit outputs globals secrets;
                };
              home-manager.users = {
                ${globals.username} = {
                  imports = [
                    ./home
                    ./home/${globals.username}.nix
                  ];
                };
                root = {
                  imports = [
                    ./home
                    ./home/root.nix
                  ];
                };
              };
            }
            vscode-server.nixosModules.default
          ]
          ++ gitwatch.modules;
      };
      jupiter = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            outputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules =
          [
            ./hosts/jupiter
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "ha-bak";
              home-manager.extraSpecialArgs =
                inputs
                // {
                  inherit outputs globals secrets;
                };
              home-manager.users = {
                ${globals.username} = {
                  imports = [
                    ./home
                    ./home/${globals.username}.nix
                  ];
                };
                root = {
                  imports = [
                    ./home
                    ./home/root.nix
                  ];
                };
              };
            }
            vscode-server.nixosModules.default
          ]
          ++ gitwatch.modules;
      };
      uranus = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            outputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules = [
          ./hosts/uranus
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "ha-bak";
            home-manager.extraSpecialArgs =
              inputs
              // {
                inherit outputs globals secrets;
              };
            home-manager.users = {
              ${globals.username} = {
                imports = [
                  ./home
                  ./home/${globals.username}.nix
                ];
              };
              root = {
                imports = [
                  ./home
                  ./home/root.nix
                ];
              };
            };
          }
        ];
      };
      vulcain = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
          inherit
            inputs
            outputs
            globals
            secrets
            ;
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        };
        modules =
          [
            ./hosts/vulcain
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "ha-bak";
              home-manager.extraSpecialArgs =
                inputs
                // {
                  inherit outputs globals secrets;
                };
              home-manager.users = {
                ${globals.username} = {
                  imports = [
                    ./home
                    ./home/${globals.username}.nix
                  ];
                };
                root = {
                  imports = [
                    ./home
                    ./home/root.nix
                  ];
                };
              };
            }
            vscode-server.nixosModules.default
          ]
          ++ gitwatch.modules;
      };
    };
  };
}
