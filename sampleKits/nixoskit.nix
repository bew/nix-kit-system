# Example Kit: a NixOS-based module system.
#
# It reuses NixOS's module system by replacing kitsys's `evalModules` call with
# `lib.nixosSystem` through `customEval`.

{ nixpkgs, kit-system }:
# (required inputs)

let
  kitsys = kit-system.lib.kitsys;
in
kitsys.newKit {
  meta.name = "Example NixOS kit (nixosSystem based)";
  class = "nixos";

  # No base modules of its own: NixOS's options and modules live in the nixpkgs repo and are
  # injected through `customEval` below.
  baseModules = [ ];

  # NixOS declares `assertions`/`warnings` itself, so kitsys must not declare them again.
  declareAssertWarnOptions = false;

  # NixOS modules need `pkgs`; requiring it reports a missing one early.
  # This adds `_module.args.pkgs`.
  requirePkgs = true;

  # Expose the built system closure flat on the Kit Config.
  exportedToplevelFields = { config, ... }: {
    inherit (config.system.build) toplevel;
  };

  # Replace the default bare `lib.evalModules` with `lib.nixosSystem`:
  customEval = (
    args@{ lib, pkgs, modules, ... }:
    nixpkgs.lib.nixosSystem {
      inherit pkgs;
      modules = modules ++ [
        # `pkgs` alone leaves `nixpkgs.hostPlatform` undefined, which NixOS reads in places; set it
        # from the passed `pkgs`. Default priority keeps a user-provided platform authoritative.
        { nixpkgs.hostPlatform = lib.mkDefault pkgs.stdenv.hostPlatform.system; }
      ];
      specialArgs = args.specialArgs or { };
    }
  );
}
