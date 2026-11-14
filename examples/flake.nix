{
  description = "Example kits built with kit-system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kit-system.url = "path:..";
  };

  outputs = inputs@{ nixpkgs, kit-system, ... }: (
    let
      systems = [ "aarch64-darwin" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsForSys = system: nixpkgs.legacyPackages.${system};

      # The example kit configs are evaluated for one concrete system, so their exported
      # packages (e.g. `activationPackage`) are directly `nix build`-able.
      exampleSystem = "x86_64-linux";

      homekit = kit-system.sampleKits.homekit {
        inherit nixpkgs;
        inherit (inputs) home-manager;
      };

      nixoskit = kit-system.sampleKits.nixoskit {
        inherit nixpkgs;
      };

      nixvimkit = kit-system.sampleKits.nixvimkit {
        inherit nixpkgs;
        inherit (inputs) nixvim;
      };
    in {
      integration-tests = forAllSystems (system: [
        (import ./test-homekit.nix {
          inherit homekit;
          pkgs = pkgsForSys system;
        })
        (import ./test-nixoskit.nix {
          inherit nixoskit;
          pkgs = pkgsForSys system;
        })
        (import ./test-nixvimkit.nix {
          inherit nixvimkit;
          pkgs = pkgsForSys system;
        })
      ]);

      # == Example Kits:

      kits.homekit = homekit;
      kits.nixoskit = nixoskit;
      kits.nixvimkit = nixvimkit;

      # == Example Kit Configs:

      # An example homekit config.
      # Build it with `nix build ./examples#kitConfigs.homekit.example-home.activationPackage`
      kitConfigs.homekit.example-home = (
        homekit.eval {
          pkgs = pkgsForSys exampleSystem;
          configModule = ./example-config.homekit-module.nix;
        }
      );

      # An example NixOS system.
      # Build it with `nix build ./examples#kitConfigs.nixoskit.example-system.toplevel`
      kitConfigs.nixoskit.example-system = (
        nixoskit.eval {
          pkgs = pkgsForSys exampleSystem;
          configModule = ./example-config.nixoskit-module.nix;
        }
      );

      # An example neovim configuration.
      # Build it with `nix build ./examples#kitConfigs.nixvimkit.example-nvim.build.package`
      kitConfigs.nixvimkit.example-nvim = (
        nixvimkit.eval {
          pkgs = pkgsForSys exampleSystem;
          configModule = ./example-config.nixvimkit-module.nix;
        }
      );
    }
  );
}
