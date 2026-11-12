# Example Kit: a home-manager-based module system.
#
# It reuses HM's own modules as its module system, by replacing kitsys's plain
# `evalModules` call with HM's module set through `customEval`.
# (the same thing `home-manager.lib.homeManagerConfiguration` does internally)

{ nixpkgs, home-manager, nix-kit-system }:
let
  kitsys = nix-kit-system.lib.kitsys;

  # HM's extended lib (nixpkgs' lib plus its own additions).
  # note: HM's modules expect this as their `lib` module arg, so the kit evaluates with it.
  # note: built from the `nixpkgs` *input*'s lib, not a per-system `pkgs.lib`, so the kit stays
  # system-agnostic.
  hmLib = import "${home-manager}/modules/lib/stdlib-extended.nix" nixpkgs.lib;
in
kitsys.newKit {
  meta.name = "Example home kit (home-manager based)";

  class = "homeManager";
  lib = hmLib;

  # This kit has no base modules of its own: the module system it builds on is
  # home-manager's, and those options & modules live in the home-manager repo, not here.
  # They are injected through `customEval` below (see `hmModules`).
  baseModules = [ ];

  # home-manager declares the `lib` & nixpkgs' `assertions`/`warnings` options itself
  # → so kitsys must not declare them again.
  declareLibOption = false;
  declareAssertWarnOptions = false;

  # Expose HM's built activation package flat on the Kit Config, as
  # `homeManagerConfiguration` would.
  exportedToplevelFields = { config, ... }: {
    inherit (config.home) activationPackage;
  };

  # Replace kitsys's `evalModules` call with HM's module set.
  # Returns the *raw* `evalModules` result, so `extendWith` keeps working.
  #
  # `pkgs` is taken from the eval args (the caller of `eval` supplies it), so the kit itself stays
  # system-agnostic: one kit instance serves every system.
  customEval =
    args@{ lib, pkgs, class, modules, ... }:
    let
      # HM's modules, assembled from the `pkgs` this eval runs with.
      hmModules = import "${home-manager}/modules/modules.nix" {
        inherit pkgs lib;
      };
    in
    lib.evalModules (
      # `pkgs` is consumed here, so it must not reach `evalModules` (which rejects unknown args).
      (builtins.removeAttrs args [ "lib" "pkgs" "modules" ])
      // {
        inherit class;
        modules = modules ++ hmModules;
        specialArgs = (
          {
            # injects `modulesPath` (HM's `modules/` directory) as a module arg,
            # some of HM's bundled modules (e.g. news entries) reference it.
            modulesPath = "${home-manager}/modules";
          }
          // (args.specialArgs or { })
        );
      }
    );
}
