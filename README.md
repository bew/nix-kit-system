# Nix Kit System - Define extensible Nix module systems for specific use-cases

You define a **Kit** — a module system for one use-case — and evaluate **Kit modules** into a **Kit Config**.

This flake exposes `kitsys`, a small Nix library that turns `lib.evalModules` into a *nestable* config module system.

> [!NOTE]
> This flake was extracted from my [dotfiles](https://github.com/bew/dotfiles) repo, where it backs my _toolkit_ module systems for nvim, zsh, tmux, …

## Motivation

The **Kit** system was driven by these goals:
- **A solid base for many module systems**: every use-case (NixOS, NixVim, a zsh toolkit, …) needs the same scaffolding — an eval entry point, a `lib` option, assertions and warnings.
  `kitsys` supplies that scaffolding, so a kit only declares what is specific to it.
- **Extension after evaluation** (also called _refinement_): a **Kit Config** carries `lib.extendWith`, which re-evaluates the same kit with an extra module and returns a new config.
  These extensions can chain, and the extra module can read the config values from before the extension through the `prevConfig` module arg.

## Concepts

A **Kit** is a thin wrapper around a [Nix Module System][nix-module-system] for a specific use-case.
It adds the kit's name and metadata, makes the module system easy to share, and evaluates it with extension support.

A **Kit Config** is the result of evaluating a **Kit**: it holds the resolved option values, and can be refined/extended afterwards.

A **Kit module** is a [_Nix module_][nix-module-system] written for a **Kit**.

## Quick start

Add the flake as an input:
```nix
# flake.nix
inputs.kit-system.url = "github:bew/nix-kit-system";
```

Defining a **Kit** and evaluating a **Kit module** for that **Kit** are separate steps.

The snippets below assume `kitsys = inputs.kit-system.lib.kitsys`.

**1. Define a kit**:
```nix
mykit = kitsys.newKit {
  meta.name = "My kit for simple greetings";
  class = "mykit";
  baseModules = [
    ./base.mykit-module.nix
    { _module.args.pkgs = pkgs; } # (if needed for your kit)
  ];
};
```

**2. Evaluate a module for a kit**:
```nix
myConfig = mykit.eval {
  lib = inputs.nixpkgs.lib;
  configModule = ./path/to/your/bew-config.mykit-module.nix;
  # or in attrset form:
  # configModule = { /* your option values */ };
};
```

**3. Extend an evaluated kit config** when needed:
```nix
myCustomConfig = myConfig.lib.extendWith ({ lib, prevConfig, ... }: {
  /* override or add options; `prevConfig` holds the config values from before _this_ extension */
});
```

## Exposing **Kit**s & **Kit config**s on your flake

A flake that defines a **Kit**, or evaluates a **Kit Config**, can expose them for other flakes to consume:
- `kits.<name>` — a built **Kit**, ready to `eval`.
- `kitConfigs.<name>` — an evaluated **Kit Config**, ready to use.

```nix
{
  outputs = { kit-system, nixpkgs, ... }: let
    kitsys = kit-system.lib.kitsys;

    mykit = kitsys.newKit {
      meta.name = "My kit for simple greetings";
      class = "mykit";
      baseModules = [ ./my-base.nix ];
    };
  in {
    kits = { inherit mykit; };

    kitConfigs."mykit-bew" = mykit.eval {
      lib = nixpkgs.lib;
      configModule = ./bew-config.mykit-module.nix;
    };
  };
}
```

## Writing **Kit modules**

A **Kit** is normally paired with several kinds of **Kit modules**:
- its _base module_, which declares the kit's options and base configs
- potential _generic modules_, which add options/configs any kit can reuse
- _config modules_, the toplevel entrypoint for a **Kit** evaluation, yielding a **Kit Config**.
- any other _module_ written for that kit

All of them are ordinary [Nix modules][nix-module-system]: they may `imports` further modules, declare options, set values, and they all receive the module args the **Kit** injects.

A **Kit module** may declare its _nominal module class_ with a top-level `_class = "<class>";`.
When the **Kit** definition sets `class`, `evalModules` rejects a module whose `_class` differs.

### Writing a _base module_

The kit's _base module_ is usually named `base.<thing>kit-module.nix` or `<thing>-base.kit-module.nix`.

Example file names (these are suggestions):
- `base.wrapkit-module.nix`, the _base module_ for `wrapkit`
- `base.toolkit-module.nix`, the _base module_ for `toolkit`
- `zshkit-base.toolkit-module.nix`, for a _base module_ derived from another **kit module**

A _base module_ declares the kit's options and implements their defaults.
Such module is passed in the `baseModules` list of `kitsys.newKit`.

Example _base module_:
```nix
{ config, lib, ... }:
let
  cfg = config.mythingnamespace;
in {
  _class = "mykit";

  options = {
    mythingnamespace.thing = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
    };
  };

  config = {
    # helpers the kit's configs may call, read back as `config.lib.myHelper`
    lib.myHelper = n: "thing is: ${cfg.thing}; given n + 1 is: ${n + 1}";

    # invariants belong in assertions (warnings are non-fatal)
    assertions = [
      {
        assertion = cfg.thing != "";
        message = "thing must not be empty";
      }
    ];
  };
}
```

### Writing a _generic module_

A _generic module_ is usually named `<topic>.kit-module.nix`.

Example file names (these are suggestions):
- `dynpaths.kit-module.nix`, a _generic module_ about dynamic paths
- `dir.kit-module.nix`, a _generic module_ about describing directory content

A _generic module_ adds options or configs any kit can reuse.
Such module can be passed anywhere: `baseModules` (in `newKit`), `moreModules` (in `eval`), `imports` in any module.

Example _generic module_:
```nix
{ config, lib, ... }:
let
  cfg = config.greeting;
in {
  options = {
    greeting.subject = lib.mkOption {
      description = "The subject of a greeting";
      type = lib.types.str;
      default = "world";
    };
  };

  config = {
    lib.sayGreeting = "hello, ${cfg.subject}!";
  };
}
```

### Writing a _config module_ or a _module_ for a kit

A _config module_ for a kit is usually named `<what>-config.<thing>kit-module.nix`, for a toplevel entrypoint of a **Kit**.
Any other _module_ for a kit is usually named `<what>.<thing>kit-module.nix`.

Example file names (these are suggestions):
- `minimal-config.zshkit-module.nix`, a _config module_ for `zshkit`
- `bew-config.zshkit-module.nix`, a _config module_ for `zshkit`
- `languages-support.nvimkit-module.nix`, a _module_ for `nvimkit`

A _config module_ or _module_ can do anything for its needs 🤷.
Such module is passed as `configModule` to the `eval` function, or in any `imports`.

Example _module_:
```nix
{
  _class = "mykit";
  mythingnamespace.thing = "configured-value";
}
```

## How it works

Each `mykit.eval args` call runs `lib.evalModules` over this module list, in order:
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

The flake exposes a single function: `lib.kitsys.newKit`.

**`kitsys.newKit` args** (the kit definition):

| Arg | Default | Description |
| --- | --- | --- |
| `meta` | `{}` | Arbitrary metadata about the kit, such as `meta.name`. |
| `class` | required | Nominal module class passed to `evalModules`; a module declaring a different `_class` is rejected. |
| `baseModules` | required | Modules each evaluation starts from, declaring the kit's own options. |
| `declareLibOption` | `true` | Set `false` if `baseModules` declare `lib`. |
| `declareAssertWarnOptions` | `true` | Set `false` if `baseModules` declare these options. |

**Kit** (returned by `kitsys.newKit`):

| Field | Type | Description |
| --- | --- | --- |
| `meta` | attrset | The definition's `meta`. |
| `eval` | function | The kit's evaluation function, derived from the definition. |

**`mykit.eval` args**:

| Arg | Default | Description |
| --- | --- | --- |
| `lib` | required | The `lib` the evaluation runs with; also what config modules see as the module-arg `lib`. |
| `configModule` | required | The module holding the option values to evaluate. |
| `moreModules` | `[]` | Further modules appended after `configModule`. |

Any other argument is forwarded to `evalModules`, which rejects arguments it does not know.

**Kit Config** (returned by `mykit.eval` / `lib.extendWith`):

| Attr | Description |
| --- | --- |
| `lib.extendWith` | Extend the config with an extra module; returns a new config. |
| `assertions` / `warnings` | Checked at every evaluation and extension. |

A `_kitState` attrset is also present, holding the kit's internal evaluation state.

## Development

Run the unit tests:
```sh
just test
```

Validate the flake outputs:
```sh
nix flake check
```

[nix-module-system]: https://nix.dev/tutorials/module-system/
