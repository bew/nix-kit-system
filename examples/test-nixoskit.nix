# Runnable example test for nixoskit.

{ pkgs, nixoskit }:
let
  lib = pkgs.lib;

  config = nixoskit.eval {
    inherit pkgs;
    configModule = import ./example-config.nixoskit-module.nix;
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
    # NixOS's own options are present.
    "test.nixos-option-visible" = {
      expr = config.networking.hostName;
      expected = "example";
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
    # Exported as a top-level field.
    "test.toplevel-present" = {
      expr = lib.isDerivation config.toplevel;
      expected = true;
    };
    # Available on the extended config too.
    "test.toplevel-survives-extend" = {
      expr = lib.isDerivation extended.toplevel;
      expected = true;
    };
  };

  results = lib.runTests tests;
in
if results == [ ]
then "nixoskit example tests successful ✨"
else throw (builtins.toJSON results)
