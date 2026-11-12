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

  # A kit whose eval is driven by a custom `evalModules` wrapper, as a use-case kit would.
  # It tags the module args, and records how many modules the wrapper was handed.
  # A re-run of this wrapper can only be fed a different module list, so that count is the signal
  # `test.12custom-eval-not-rerun-on-extend` asserts on.
  # Blind spot: a re-run that is handed the same module list, then extends, looks the same.
  minikitWithCustomEval = kitsys.newKit (minikitDefArgs // {
    customEval = args@{ lib, class, modules, ... }:
      lib.evalModules ((builtins.removeAttrs args [ "lib" "modules" ]) // {
        inherit class;
        modules = modules ++ [
          (let ty = lib.types; in {
            options = {
              seenModules = lib.mkOption {
                type = ty.ints.unsigned;
              };
            };
            config = {
              _module.args.customEvalTag = "custom";
              seenModules = builtins.length modules;
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

  # A kit exporting an extra top-level field, derived from the eval result.
  minikitWithExportedFields = kitsys.newKit (minikitDefArgs // {
    exportedToplevelFields = { config, ... }: {
      doubled = config.val;
    };
  });

  withExportedFields = minikitWithExportedFields.eval {
    inherit lib;
    configModule = { val = "exported-value"; };
  };

  exportedFieldsNested = withExportedFields.extendWith ({lib, ...}: {
    val = lib.mkForce "exported-value-after-extend";
  });

  # `val` is already a top-level option of the mini kit → exporting that name must be rejected.
  collisionRejected = let
    result = builtins.tryEval ((kitsys.newKit (minikitDefArgs // {
      exportedToplevelFields = _: { val = "shadowing-the-option"; };
    })).eval {
      inherit lib;
      configModule = { val = "x"; };
    }).val;
  in !result.success;

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

  # `pkgs` on `eval`: it provides `lib` (as `pkgs.lib`) when nothing else does, and is injected as
  # `_module.args.pkgs` by the default eval (a `customEval` gets it as a plain eval arg instead).
  pkgsDerivedLib = minikit.eval {
    pkgs = { lib = tagLib "from-pkgs"; };
    configModule = { libTag, ... }: { val = libTag; };
  };

  pkgsInjected = minikit.eval {
    pkgs = { inherit lib; marker = "the-pkgs"; };
    configModule = { pkgs, ... }: { val = pkgs.marker; };
  };

  # A kit-wide `lib` beats `pkgs.lib` (a kit may need its own extended lib, e.g. home-manager's).
  kitLibBeatsPkgsLib = minikitWithLib.eval {
    pkgs = { lib = tagLib "from-pkgs"; };
    configModule = { libTag, ... }: { val = libTag; };
  };

  # A kit declaring that `eval` must be given a `pkgs`.
  minikitRequiringPkgs = kitsys.newKit (minikitDefArgs // {
    requirePkgs = true;
  });

  # `val` is forced to run `eval`, which must throw before reaching the modules.
  pkgsRequiredButMissing = let
    result = builtins.tryEval (minikitRequiringPkgs.eval {
      inherit lib;
      configModule = { val = "x"; };
    }).val;
  in
  !result.success;

  pkgsRequiredAndGiven = minikitRequiringPkgs.eval {
    pkgs = { inherit lib; };
    configModule = { val = "given-pkgs"; };
  };

  # The eval results under test, grouped for `tests.nix`.
  sampleConfigs = {
    inherit init nested nestedAgain withWarn;
    inherit libFromNewKit libFromEval;
    inherit customEval customEvalNested;
    inherit withExportedFields exportedFieldsNested;
    inherit collisionRejected;
    inherit pkgsDerivedLib pkgsInjected kitLibBeatsPkgsLib;
    inherit pkgsRequiredButMissing pkgsRequiredAndGiven;
  };

  tests = import ./tests.nix {
    inherit sampleConfigs;
  };

  nicer_testResults = let
    testResults = lib.runTests tests;
    fmtTestNames = lib.concatStringsSep ", " (builtins.attrNames tests);
  in (
    if testResults == []
    then "Unit tests successful ✨ (${fmtTestNames})"
    else testResults
  );

in nicer_testResults
# in sampleConfigs # for DEBUG in repl

# Run with `nix eval -f tests/runner.nix`
# Add `--json | jq .` for better readability of test result failures
