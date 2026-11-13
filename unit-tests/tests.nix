{
  sampleConfigs,
}:

# NOTE: Test names _must_ start with `test` to be considered by `runTests`.
# (note: numbers in test name used to ensure test ordering)
{
  # Test value propagation across config extensions
  "test.0initial" = {
    expr = sampleConfigs.init.val;
    expected = "first-value";
  };
  "test.1nested" = {
    expr = sampleConfigs.nested.val;
    expected = "second-value, prev not used";
  };
  "test.2doubly-nested" = {
    expr = sampleConfigs.nestedAgain.val;
    expected = "third-value (was second-value, prev not used)";
  };
  # Test nesting level info in kit state
  "test.0initial.level" = {
    expr = sampleConfigs.init._kitState.nestingLevel;
    expected = 0;
  };
  "test.1nested.level" = {
    expr = sampleConfigs.nested._kitState.nestingLevel;
    expected = 1;
  };
  "test.2doubly-nested.level" = {
    expr = sampleConfigs.nestedAgain._kitState.nestingLevel;
    expected = 2;
  };
  # Test lib functions are inherited across config extensions
  "test.5lib-func-works" = {
    expr = sampleConfigs.init.lib.doubleThat 3;
    expected = 6;
  };
  "test.6lib-func-inherited-after-extend" = {
    expr = sampleConfigs.nested.lib.doubleThat 4;
    expected = 8;
  };
  # Other tests
  "test.7lib-from-newkit" = {
    expr = sampleConfigs.libFromNewKit.val;
    expected = "newKit";
  };
  "test.8lib-from-eval-wins" = {
    expr = sampleConfigs.libFromEval.val;
    expected = "eval";
  };
  "test.with-warning" = {
    expr = sampleConfigs.withWarn.warnings;
    # note: extensions are put before for list merges
    expected = [ "test warning is working" ];
  };
  # Test custom `customEval` wrapper
  "test.9custom-eval-used" = {
    expr = sampleConfigs.customEval.val;
    expected = "custom";
  };
  "test.10custom-eval-extend-chains" = {
    expr = sampleConfigs.customEvalNested.val;
    expected = "extended-after-custom-eval";
  };
  "test.11custom-eval-extend-nesting-level" = {
    expr = sampleConfigs.customEvalNested._kitState.nestingLevel;
    expected = 1;
  };
  # `extendWith` reuses the recorded eval's `extendModules`, so the module list the `customEval`
  # wrapper was handed must not change.
  # Blind spot: a re-run that is handed the same module list, then extends, is not caught.
  "test.12custom-eval-not-rerun-on-extend" = {
    expr = sampleConfigs.customEvalNested.seenModules == sampleConfigs.customEval.seenModules;
    expected = true;
  };
  # Test extra top-level fields exported by the kit
  "test.13exported-field-present" = {
    expr = sampleConfigs.withExportedFields.doubled;
    expected = "exported-value";
  };
  # kitsys re-derives exported fields on each eval, so they survive extension
  "test.14exported-field-survives-extend" = {
    expr = sampleConfigs.exportedFieldsNested.doubled;
    expected = "exported-value-after-extend";
  };
  # An exported name colliding with a top-level option must be rejected
  "test.15exported-field-collision-rejected" = {
    expr = sampleConfigs.collisionRejected;
    expected = true;
  };
  # `pkgs` passed to `eval`
  "test.16pkgs-derives-lib" = {
    expr = sampleConfigs.pkgsDerivedLib.val;
    expected = "from-pkgs";
  };
  "test.17pkgs-reaches-modules" = {
    expr = sampleConfigs.pkgsInjected.val;
    expected = "the-pkgs";
  };
  # A kit's own `lib` takes priority over `pkgs.lib`
  "test.18kit-lib-beats-pkgs-lib" = {
    expr = sampleConfigs.kitLibBeatsPkgsLib.val;
    expected = "newKit";
  };
  # `requirePkgs = true`: `eval` must be given a `pkgs`
  "test.19require-pkgs-missing-throws" = {
    expr = sampleConfigs.pkgsRequiredButMissing;
    expected = true;
  };
  "test.20require-pkgs-given-ok" = {
    expr = sampleConfigs.pkgsRequiredAndGiven.val;
    expected = "given-pkgs";
  };
  # `disableExtensionSupport = true`: eval works, `extendWith` throws, no `_kitState`
  "test.21no-extension-config-ok" = {
    expr = sampleConfigs.noExtensionConfig.val;
    expected = "no-extension";
  };
  "test.22no-extension-extend-throws" = {
    expr = sampleConfigs.noExtensionExtendThrows;
    expected = true;
  };
  "test.23no-extension-has-no-kit-state" = {
    expr = sampleConfigs.noExtensionHasNoKitState;
    expected = true;
  };
}
