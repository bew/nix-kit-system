let
  # Unpinned fetch of nixpkgs' lib: the tests only need a recent `lib` (and `runTests`).
  lib = (builtins.getFlake "github:nix-community/nixpkgs.lib").lib;

  kitsys = import ../kitsys.nix;

  # Plain definition of the mini kit (formerly `mini-kit/kit.nix`), reused by the variants below.
  minikitDefArgs = {
    meta.name = "Mini test kit";
    baseModules = [ ./mini-kit/base.nix ];
    class = "test-kit";
  };

  minikit = kitsys.newKit minikitDefArgs;

  # `lib` variants tagging the evals they drive, so tests can tell which lib was used.
  # (`evalModules` has no `lib` arg: a module's `lib` comes from the lib's own `modules.nix`,
  #  so tagging happens through a wrapper on `evalModules`.)
  tagLib = tag: lib // {
    evalModules = args: lib.evalModules (args // {
      modules = args.modules ++ [ { _module.args.libTag = tag; } ];
    });
  };

  minikitWithLib = kitsys.newKit (minikitDefArgs // {
    lib = tagLib "newKit";
  });

  libFromNewKit = minikitWithLib.eval {
    configModule = { libTag, ... }: { val = libTag; };
  };

  libFromEval = minikitWithLib.eval {
    lib = tagLib "eval";
    configModule = { libTag, ... }: { val = libTag; };
  };

  # A kit whose eval is driven by a custom `evalModules` wrapper, as a use-case kit would
  # (e.g. a home-manager-based kit). It tags the module args and appends a module that records —
  # through a list-valued option — how many times the wrapper actually ran.
  minikitWithCustomEval = kitsys.newKit (minikitDefArgs // {
    customEval = args@{ lib, class, modules, ... }:
      lib.evalModules ((builtins.removeAttrs args [ "lib" "modules" ]) // {
        inherit class;
        modules = modules ++ [
          (let ty = lib.types; in {
            options.customEvalRuns = lib.mkOption {
              type = ty.listOf ty.str;
            };
            config = {
              _module.args.customEvalTag = "custom";
              customEvalRuns = [ "run" ];
            };
          })
        ];
      });
  });

  customEval = minikitWithCustomEval.eval {
    inherit lib;
    configModule = { customEvalTag, ... }: { val = customEvalTag; };
  };

  # `extendWith` must keep working after a custom eval, and must NOT run `customEval` again
  # (it goes through the recorded eval's `extendModules`).
  customEvalNested = customEval.extendWith ({lib, ...}: {
    val = lib.mkForce "extended-after-custom-eval";
  });

  init = minikit.eval {
    inherit lib;
    configModule = {
      val = "first-value";
    };
  };

  nested = init.extendWith ({lib, ...}: {
    val = lib.mkForce "second-value, prev not used";
  });

  nestedAgain = nested.extendWith ({lib, prevConfig, ...}: {
    val = lib.mkOverride 45 "third-value (was ${prevConfig.val})";
    # note: mkForce has priority 50, 45 has more priority
  });

  withWarn = nestedAgain.extendWith ({lib, ...}: {
    warnings = [ "test warning is working" ];
  });

  # The eval results under test, grouped for `tests.nix`.
  sampleConfigs = {
    inherit init nested nestedAgain withWarn;
    inherit libFromNewKit libFromEval;
    inherit customEval customEvalNested;
  };

  tests = import ./tests.nix {
    inherit lib sampleConfigs;
  };

  nicer_testResults = let
    testResults = lib.runTests tests;
    fmtTestNames = lib.concatStringsSep ", " (builtins.attrNames tests);
  in (
    if testResults == []
    then "Tests successful ✨ (${fmtTestNames})"
    else testResults
  );

in nicer_testResults
# in sampleConfigs # for DEBUG in repl

# Run with `nix eval -f tests/runner.nix`
# Add `--json | jq .` for better readability of test result failures
