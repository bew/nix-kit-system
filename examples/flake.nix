{
  description = "Example kits built with kit-system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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

      # TODO: add more sample kits!
    in {
      integration-tests = forAllSystems (system: import ./test.nix {
        inherit homekit;
        pkgs = pkgsForSys system;
      });

      # == Example Kits:
      kits.homekit = homekit;

      # == Example Kit Configs:

      # An example homekit config.
      # Build it with `nix build ./examples#kitConfigs.homekit.example-home.activationPackage`
      kitConfigs.homekit.example-home = (
        homekit.eval {
          pkgs = pkgsForSys exampleSystem;
          configModule = ./example-config.homekit-module.nix;
        }
      );
    }
  );
}
