# Runnable example test for the home-manager-based kit.
#
# Reached through the flake's `integration-tests.<system>` output; `just test` (in the repo root) runs it
# after the unit tests.
# It throws on failure so the recipe actually fails.
# The kit is system-agnostic, so `pkgs` is supplied per eval here.
{ pkgs, homekit }:
let
  lib = pkgs.lib;

  config = homekit.eval {
    inherit pkgs;
    configModule = import ./example-config.homekit-module.nix;
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
    # Proves home-manager's own options are present in the evaluated config.
    "test.home-option-visible" = {
      expr = config.home.username;
      expected = "example";
    };
    "test.extend-with-chains" = {
      expr = extended.example.greeting;
      expected = "extended";
    };
    # The kit exports home-manager's activation package as a top-level field.
    "test.activation-package-present" = {
      expr = lib.isDerivation config.activationPackage;
      expected = true;
    };
    # kitsys re-derives the exported fields on every eval, so they survive extension.
    "test.activation-package-survives-extend" = {
      expr = lib.isDerivation extended.activationPackage;
      expected = true;
    };
  };

  results = lib.runTests tests;
in
if results == [ ]
then "homekit example tests successful ✨"
else throw (builtins.toJSON results)
