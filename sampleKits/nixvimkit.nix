# Example Kit: a nixvim-based module system.
#
# It reuses nixvim's module system by replacing kitsys's `evalModules` call with
# `lib.evalNixvim` through `customEval`.

{ nixpkgs, nixvim, kit-system }:
# (required inputs)

let
  kitsys = kit-system.lib.kitsys;
in
kitsys.newKit {
  meta.name = "Example nixvim kit (evalNixvim based)";
  class = "nixvim";

  # No base modules of its own: nixvim's options and modules live in the nixvim repo and are
  # injected through `customEval` below.
  baseModules = [ ];

  # nixvim declares `assertions`/`warnings` itself, so kitsys must not declare them again.
  declareAssertWarnOptions = false;

  # nixvim modules need `pkgs`; requiring it reports a missing one early.
  # This adds `_module.args.pkgs`.
  requirePkgs = true;

  # `lib.evalNixvim` returns the raw `evalModules` result, so `extendWith` keeps working.
  customEval = (
    args@{ lib, pkgs, modules, ... }:
    nixvim.lib.evalNixvim {
      modules = modules ++ [
        # nixvim takes its nixpkgs instance through `nixpkgs.pkgs`, as its own
        # `makeNixvimWithModule` does; default priority keeps a user-provided value authoritative.
        { nixpkgs.pkgs = lib.mkDefault pkgs; }
      ];
      extraSpecialArgs = args.specialArgs or { };
    }
  );
}
