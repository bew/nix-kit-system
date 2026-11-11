{
  lib,
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
  # `extendWith` reuses the recorded eval's `extendModules`, so `customEval` must run only once.
  "test.12custom-eval-not-rerun-on-extend" = {
    expr = lib.length sampleConfigs.customEvalNested.customEvalRuns;
    expected = 1;
  };
}
