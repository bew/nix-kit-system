{
  description = "Example kits built with nix-kit-system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-kit-system.url = "path:..";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-kit-system,
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # One system-agnostic kit instance: `pkgs` is deferred to each `eval` call.
      homekit = import ./homekit.nix { inherit nixpkgs home-manager nix-kit-system; };
    in
    {
      # Example Kit: a home-manager-based module system.
      # Not per-system: the kit takes `pkgs` at eval time.
      kits.homekit = homekit;

      # Runnable example test, kept out of `checks.*` on purpose.
      # `just test` (in the repo root) runs it after the unit tests.
      tests = forAllSystems (pkgs: import ./test.nix { inherit pkgs homekit; });

      # The example home, buildable via `nix build ./examples#example-home`.
      packages = forAllSystems (pkgs: {
        example-home = let
          homeConfig = homekit.eval {
            inherit pkgs;
            configModule = ./example-config.homekit-module.nix;
          };
        in homeConfig.activationPackage;
      });
    };
}
