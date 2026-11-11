# kit-system - Nested config module systems for Nix

`kit-system` (`kitsys`) is a small Nix library that turns `lib.evalModules` into a *nestable* config module system.
You define a **Kit** — a module system for one use-case — and evaluate it into a **Kit Config**.

This flake was extracted from my [dotfiles] repo, where it backs my toolkit systems.

## Motivation

The **Kit** system was driven by these goals:
- **A solid base for many module systems**: every use-case (NixOS, NixVim, a zsh toolkit, …) needs the same scaffolding — an eval entry point, a `lib` option, assertions and warnings.
  `kitsys` supplies that scaffolding, so a kit only declares what is specific to it.
- **Refinement after evaluation**: a **Kit Config** carries `lib.extendWith`, which re-evaluates the same kit with an extra module and returns a new config.
  These extensions can chain, and the extra module can read the pre-extension values through `prevConfig` module arg.

## What is a Kit? What is a Kit Config?

A **Kit** is a _module system for a specific use-case_.
It is defined as an attrset and built with `kitsys.newKit`.

A **Kit Config** is the result of evaluating a **Kit**: it holds the resolved option values, and can be refined/extended afterwards.

## Quick start

Add the flake as an input:
```nix
# flake.nix
inputs.kit-system.url = "github:bew/nix-kit-system";
```

Defining a kit and evaluating a **Kit Config** are separate steps.

The snippets below assume `kitsys = inputs.kit-system.lib.kitsys`.

**1. Define a kit**:
```nix
myKit = kitsys.newKit {
  meta.name = "My kit";
  baseModules = [ ./my-base.nix ];
  class = "my-kit";
};
```

**2. Evaluate a kit config**:
```nix
myConfig = myKit.eval {
  configModule = { /* your option values */ };
}
```

**3. Refine an evaluated kit config** when needed:
```nix
myCustomConfig = myConfig.lib.extendWith ({ lib, prevConfig, ... }: {
  /* override or add options; `prevConfig` holds the config values from before _this_ extension */
})
```

## How it works

Each `myKit.eval args` call runs `lib.evalModules` over this module list, in order:
1. the injected kitsys base modules
2. the **Kit** definition's `baseModules`
3. the caller's `configModule` & `moreModules`

A **Kit** injects these base modules by default:
- the `lib` option
- the `assertions` and `warnings` options
- the `lib.extendWith` function (for after-eval config refinement)

`myConfig.lib.extendWith module` calls `prevEval.extendModules` on the recorded evaluation, bumping `_kitState.nestingLevel` and exposing the previous config to the added module as `prevConfig`.

> [!NOTE]
> Fun fact: I originally built the `extendWith` mechanism myself, before knowing that `evalModules` results can already be extended through `extendModules` 😅.

## API reference

The flake exposes a single output: `lib.kitsys.newKit`.

**`kitsys.newKit` args** (the kit definition):

| Arg | Default | Description |
| --- | --- | --- |
| `meta` | `{}` | Arbitrary metadata about the kit, such as `meta.name`. |
| `baseModules` | `[]` | Modules each evaluation starts from, declaring the kit's own options. |
| `class` | `null` | Module class passed to `evalModules`. |
| `specialArgs` | `{}` | Module args passed to every evaluation of the kit. |
| `declareLibOption` | `true` | Set `false` if `baseModules` declare `lib`. |
| `declareAssertWarnOptions` | `true` | Set `false` if `baseModules` declare these options. |

**Kit** (returned by `kitsys.newKit`):

| Field | Type | Description |
| --- | --- | --- |
| `meta` | attrset | The definition's `meta`. |
| `eval` | function | The kit's evaluation function, derived from the definition. |

**`myKit.eval` args**:

| Arg | Default | Description |
| --- | --- | --- |
| `lib` | the `lib` kitsys is built with | Module-system lib used for the evaluation. |
| `configModule` | required | The module holding the option values to evaluate. |
| `moreModules` | `[]` | Further modules appended after `configModule`. |

**Kit Config** (returned by `myKit.eval` / `lib.extendWith`):

| Attr | Description |
| --- | --- |
| `lib.extendWith` | Re-evaluate with an extra module; returns a new config. |
| `assertions` / `warnings` | Checked at every evaluation and extension. |

A `_kitState` attrset is also present, holding the kit's internal evaluation state.

## Development

Run the unit tests:
```sh
nix eval -f tests.nix
```
They use `lib.runTests` and exercise the `test-kit/` kit.

Validate the flake outputs:
```sh
nix flake check
```

[dotfiles]: https://github.com/bew/dotfiles
