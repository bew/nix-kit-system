# Runnable example test for the nixvimkit.

{ pkgs, nixvimkit }:
let
  lib = pkgs.lib;

  config = nixvimkit.eval {
    inherit pkgs;
    configModule = import ./example-config.nixvimkit-module.nix;
  };

  # `extendWith` must keep working on a kit built with `customEval`.
  extended = config.extendWith ({ ... }: {
    example.greeting = lib.mkForce "extended";
  });

  tests = {
    "test.example-option" = {
      expr = config.example.greeting;
      expected = "hi";
    };
    # nixvim's own options are present.
    "test.nixvim-option-visible" = {
      expr = config.colorscheme;
      expected = "habamax";
    };
    # Plugin options are reachable too.
    "test.plugin-enabled" = {
      expr = config.plugins.lualine.enable;
      expected = true;
    };
    # The caller's `pkgs` is reused, not a fresh nixpkgs.
    "test.pkgs-reused" = {
      expr = config.nixpkgs.pkgs.stdenv.hostPlatform.system;
      expected = pkgs.stdenv.hostPlatform.system;
    };
    "test.extend-with-chains" = {
      expr = extended.example.greeting;
      expected = "extended";
    };
    # Reachable at its shallow location.
    "test.package-present" = {
      expr = lib.isDerivation config.build.package;
      expected = true;
    };
    # Available on the extended config too.
    "test.package-survives-extend" = {
      expr = lib.isDerivation extended.build.package;
      expected = true;
    };
  };

  results = lib.runTests tests;
in
if results == [ ]
then "nixvimkit example tests successful ✨"
else throw (builtins.toJSON results)
