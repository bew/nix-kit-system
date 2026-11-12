let
  checkAssertsAndWarnings = lib: config: (
    # Check assertions & warnings: (returns the evaluated config if all good)
    # - show all warnings
    # - fail with messages for all false asserts
    lib.asserts.checkAssertWarn
      config.assertions
      config.warnings
      config
  );

  # A module that declares the _required_ `lib` option (needed for defining nested eval below)
  declareLibOptionModule = {lib, ...}: let ty = lib.types; in {
    options.lib = lib.mkOption {
      description = "Set of lib functions to help write configs";
      type = ty.attrsOf (ty.uniq ty.anything);
    };
  };

  # Interesting related work, to follow:
  # - Reusable assertions (aka, integrate them in the module system)
  #   <https://github.com/NixOS/nixpkgs/pull/207187>
  # - structured attrs for warnings/assertions
  #   <https://github.com/NixOS/nixpkgs/pull/342372>
  declareAssertWarnOptionsModule = {lib, ...}: let ty = lib.types; in {
    options.assertions = lib.mkOption {
      description = "List of assertions to check";
      type = ty.listOf (ty.submodule {
        options = {
          assertion = lib.mkOption {
            type = ty.bool;
            description = "Assertion condition that must be true";
          };
          message = lib.mkOption {
            type = ty.str;
            description = "Error message to display when assertion fails";
          };
        };
      });
      default = [];
    };

    options.warnings = lib.mkOption {
      description = "List of warning messages to display";
      type = ty.listOf ty.str;
      default = [];
    };
  };

  # A module declaring the `_kitState` option, where the extension helper keeps its state.
  # 👉 Allows to take a full kit-based config and refine it later as needed.
  declareConfigExtensionHelperModule = {lib, ...}: {
    options._kitState = let ty = lib.types; in {
      # Not strictly necessary, but can be useful information.
      nestingLevel = lib.mkOption {
        description = "Nesting level of the current kitsys eval, overridden with each config extension";
        type = ty.ints.unsigned;
        default = 0;
      };
      # NOTE: This is needed to be able to access the current eval in the impl of `extendWith`.
      currentEval = lib.mkOption {
        type = ty.raw; # zero smart, zero merging
        # note: initial value is set in `kit.eval` with the option-default's priority
      };
    };
  };

  # Default implementation for `newKit`'s `customEval`:
  # A thin wrapper around `lib.evalModules` that only assembles `class` and `modules`
  # and forwards ~every other argument the caller passed.
  #
  # note: `pkgs` is not forwarded if given, it is injected as the `_module.args.pkgs` instead,
  # with the lowest priority so a kit or a caller can override it if needed.
  defaultEval = args@{ lib, class, modules, pkgs ? null, ... }: (
    let
      defaultPkgsModule = (
        if pkgs != null
        then { _module.args.pkgs = lib.mkDefault pkgs; }
        else {}
      );
    in lib.evalModules ((builtins.removeAttrs args [ "lib" "class" "modules" "pkgs" ]) // {
      inherit class;
      modules = modules ++ [defaultPkgsModule];
    })
  );

in {
  # Build a kit from a plain definition attrset, and return that kit.
  # The returned kit carries back `meta`, and derives `eval` from the definition.
  newKit = {
    # Arbitrary metadata about the kit, such as `meta.name`.
    meta ? {},
    # Module class passed to `evalModules`.
    class,
    # The modules every evaluation of the kit starts from, declaring the kit's own options.
    baseModules,

    # Module-system lib used for the evaluation, as a kit-wide default.
    # A `lib` passed to `eval` takes priority over this one; `eval`'s `pkgs` is the last resort.
    lib ? null,

    # Set to `false` if `lib` option is already defined in `baseModules` to avoid conflicting
    # definitions.
    declareLibOption ? true,

    # Set to `false` if `assertions`/`warnings` options are already defined in `baseModules` to
    # avoid conflicting definitions.
    declareAssertWarnOptions ? true,

    # When `true`, `eval` throws unless `pkgs` is passed to it.
    # Use it so the missing `pkgs` is reported early, instead of failing deep in the stack.
    requirePkgs ? false,

    # Replaces the `lib.evalModules` call each `eval` would otherwise run, e.g. to wrap it with a
    # use-case-specific evaluator (such as home-manager's).
    #
    # CONTRACT:
    # - It receives every argument the underlying `evalModules` call needs: the effective `lib`,
    #   the kit's `class`, the fully-assembled `modules`, plus any extra arg the caller passed to
    #   `eval` (e.g. `specialArgs`). `lib` must NOT be forwarded to `evalModules`.
    # - It must return the raw `evalModules` result — or at least an attrset exposing `config`,
    #   `options` and `extendModules`. kitsys needs:
    #     - `config`        → to run the assertions/warnings check,
    #     - `options`       → read by `extendWith` (for `_kitState.nestingLevel`'s priority),
    #     - `extendModules` → to drive chained config extension.
    #   In particular, the returned `extendModules` must keep closing over the same `modules` +
    #   `specialArgs`, otherwise `extendWith` silently loses them.
    customEval ? defaultEval,

    # Extra top-level fields each Kit Config should carry, derived from the evaluated config.
    #
    # CONTRACT:
    # - A single function receiving the whole raw `evalModules` result, so it may read `config`
    #   (and, if ever needed, `options` or `extendModules`).
    # - It returns an attrset of `fieldName = value`, added flat onto the Kit Config.
    # - kitsys applies it on every evaluation, including each `extendWith` extension, so the fields
    #   stay present and up-to-date after extension chaining.
    #   Only what the function returns is added: any additional attr a `customEval` puts on-top of
    #   `evalModules`'s result is ignored.
    # - A returned name must not collide with a top-level option name or with `extendWith`; kitsys
    #   throws in that case.
    # - The function must only return fields the eval can produce; guard the optional ones itself
    #   (e.g. `lib.optionalAttrs (config ? home) { … }`).
    exportedToplevelFields ? (_: {}),
  }:
  let
    kitLib = lib; # Captured before `eval`'s own `lib` arg shadows it

    # The `lib` given to `eval` wins, then the kit-wide `lib`, then `pkgs.lib` (when `pkgs!=null`).
    # Fails if none of them is set.
    effectiveLib = evalLib: pkgs: (
      if evalLib != null
      then evalLib
      else if kitLib != null
      then kitLib
      else if pkgs != null
      then pkgs.lib
      else throw "kitsys.eval: no `lib` given; pass it to `newKit`, to `eval`, or pass `pkgs` to `eval`"
    );

    kitsysBaseModules = [
      (if declareLibOption then declareLibOptionModule else {})
      (if declareAssertWarnOptions then declareAssertWarnOptionsModule else {})
      declareConfigExtensionHelperModule
    ];

    eval = {
      # Module-system lib used for the evaluation.
      # Defaults to the `lib` given to `newKit`, or `pkgs.lib` as a last resort (when `pkgs!=null`).
      lib ? null,
      # The caller's module: the option values to evaluate.
      configModule,
      # Further modules appended after `configModule`.
      moreModules ? [],
      # System-specific `pkgs` for this evaluation — the common case for a kit whose modules need it.
      # It is forwarded to the kit's `customEval`, and (with the default one) injected as the
      # `_module.args.pkgs` module arg.
      # It also provides `lib` when no `lib` is otherwise set.
      pkgs ? null,
      ...
    }@evalArgs:
    let
      evalLib = evalArgs.lib or null; # Captured & renamed for readability

      # Shadow 'lib' with the actual effective lib
      lib = effectiveLib evalLib pkgs;

      # Everything else the caller passes goes straight to the customEval or defaultEval, which in
      # turn should pass them to nixpkgs's `evalModules`, which rejects arguments it doesn't know.
      evalArgsExtra = builtins.removeAttrs evalArgs [ "configModule" "moreModules" "lib" ];

      # Ensure that `pkgs` was given when the kit definition requires it.
      # Checked early.
      checkRequiredPkgs = result: (
        # Fail early when the kit declares it needs `pkgs` and the caller did not pass one.
        if requirePkgs && pkgs == null
        then throw ''kitsys.eval: kit "${meta.name or "unnamed"}" requires `pkgs`; pass it to `eval` call''
        else result
      );

      evaluated = checkRequiredPkgs (
        customEval (evalArgsExtra // {
          inherit lib class;
          modules = (
            kitsysBaseModules
            ++ baseModules
            ++ [ configModule ]
            ++ moreModules
            ++ [
              # Initialize the state with the current eval, using option-default priority to ensure
              # all _kitState options have the same priority.
              { _kitState.currentEval = lib.mkOptionDefault evaluated; }
            ]
          );
        })
      );

      # Turn a raw `evalModules` result into a Kit Config: run the assertions/warnings check, then
      # attach the extension helper so that extensions can chain.
      toKitConfig = rawEval: let
        rawKitConfig = checkAssertsAndWarnings lib rawEval.config;
        prev_kitState = rawKitConfig._kitState;
        # NOTE: We need a higher priority (less is more) for the options set below, to make sure
        # that 2+ nesting evals won't have conflicting option definitions when overriding values.
        higherPrio = rawEval.options._kitState.nestingLevel.highestPrio - 1;

        exportedFields = exportedToplevelFields rawEval;

        checkCollidingExports = finalKitConfig: let
          # Toplevel names the Kit Config reserves on the final kit config
          reservedExportNames = [ "extendWith" ];
          collidingNames = (
            builtins.filter
              (name: builtins.hasAttr name rawKitConfig || builtins.elem name reservedExportNames)
              (builtins.attrNames exportedFields)
          );
        in (
          if collidingNames != []
          then throw "kitsys: exportedToplevelFields names collide with the Kit Config: ${lib.concatStringsSep ", " collidingNames}"
          else finalKitConfig
        );

        # Extend the current Kit Config with the given module, returning a new Kit Config.
        # An extension module can read the pre-extension config through the `prevConfig` module arg.
        extendWith = module: let
          extendedEval = rawEval.extendModules {
            modules = [
              module
              {
                _kitState.nestingLevel = lib.mkOverride higherPrio (prev_kitState.nestingLevel + 1);
                # NOTE: Storing the eval in the config is necessary to be able to retrieve highestPrio
                # of an option in the previous eval.
                #
                # note: Due to Nix's laziness its value is never actually evaluated until a config
                # value from a previous config is needed.
                _kitState.currentEval = lib.mkOverride higherPrio extendedEval;

                # Expose the previous config if an extension module needs the before-extension value
                # of something.
                _module.args.prevConfig = lib.mkOverride higherPrio rawEval.config;
              }
            ];
          };
        in toKitConfig extendedEval;

        # The final attrset representing the kit config 🚀
        finalKitConfig = (
          exportedFields // rawKitConfig // {
            # NOTE: `extendWith` is a direct property of the returned Kit Config.
            # (injected last to avoid overrides & any possible conflict)
            inherit extendWith;
          }
        );

      in checkCollidingExports finalKitConfig;
      # (end of toKitConfig)

    in toKitConfig evaluated;
    # (end of eval)

  in {
    inherit meta eval;
  };
}
