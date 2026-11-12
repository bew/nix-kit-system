# Nix Kit System - Define extensible Nix module systems for specific use-cases

You define a **Kit** — a module system for one use-case — and evaluate **Kit modules** into a **Kit Config**.

This flake exposes `kitsys`, a small Nix library that turns `lib.evalModules` into a *nestable* config module system.

> [!NOTE]
> This flake was extracted from my [dotfiles] repo at ([bew/dotfiles#68d297fad](https://github.com/bew/dotfiles/commit/68d297fad3f78a5ab7807a5939b081d6a5f9a692)), where it backs my _toolkit_ module systems for nvim, zsh, tmux, …

> [!NOTE]
> The initial implementation was entirely written by hand.
> The extraction as a flake from my [dotfiles] repo, and the API rework since then, were AI-assisted.

[dotfiles]: https://github.com/bew/dotfiles

## Motivation

The **Kit** system was driven by these goals:
- **A solid base for many module systems**: every use-case (NixOS, NixVim, a zsh toolkit, …) needs the same scaffolding — an eval entry point, a `lib` option, assertions and warnings.
  `kitsys` supplies that scaffolding, so a kit only declares what is specific to it.
- **A standard way to create & share module systems**: a kit is a named, class-constrained module system with a stable eval entry point, so a module system defined once can be exposed as a flake output (`kits.<name>`) and consumed by other flakes.
- **Easy way to extend/refine a config after evaluation**: a **Kit Config** carries `extendWith`, which re-evaluates the same kit with an extra module and returns a new config.
  These extensions can chain, and the extra module can read the config values from the previous eval through the `prevConfig` module arg.

## Concepts

A **Kit** is a thin wrapper around a [Nix Module System][nix-module-system] for a specific use-case.
It adds the kit's name and metadata, makes the module system easy to share, and evaluates it with extension support.

A **Kit Config** is the result of evaluating a **Kit**: it holds the resolved option values, and can be refined/extended afterwards.

A **Kit module** is a [_Nix module_][nix-module-system] written for a **Kit**.

A **Kit** should stay system-agnostic: its definition must not depend on any particular system, so the same kit instance can be shared everywhere it is exposed.
Anything system-specific — typically `pkgs` — belongs to an evaluation: pass it to `eval` as `pkgs`, never bake it into the kit's `baseModules`.
`eval`'s `pkgs` also provides `lib` (as `pkgs.lib`) when no other `lib` is set.

## Quick start

Add the flake as an input:
```nix
# flake.nix
inputs.kit-system.url = "github:bew/nix-kit-system";
```

Defining a **Kit** and evaluating a **Kit module** for that **Kit** are separate steps.

The snippets below assume `kitsys = inputs.kit-system.lib.kitsys`, and that `pkgs` is the `pkgs` of the system being evaluated.

**1. Define a kit**:
```nix
mykit = kitsys.newKit {
  meta.name = "My kit for simple greetings";
  class = "mykit";
  baseModules = [ ./base.mykit-module.nix ];
};
```

**2. Evaluate a module for a kit**:
```nix
myConfig = mykit.eval {
  pkgs = pkgs; # system-specific inputs belong here, at eval time (`lib` then defaults to `pkgs.lib`)
  # or if the kit doesn't need `pkgs`, pass `lib` directly:
  # lib = inputs.nixpkgs.lib;

  configModule = ./path/to/your/bew-config.mykit-module.nix;
  # or in attrset form:
  # configModule = { /* your option values */ };
};
```

**3. Extend an evaluated kit config** when needed:
```nix
myCustomConfig = myConfig.extendWith ({ lib, prevConfig, ... }: {
  /* override or add options; `prevConfig` holds the config values from the previous eval */
});
```

## Exposing **Kit**s & **Kit config**s on your flake

A flake that defines a **Kit**, or evaluates a **Kit Config**, can expose them for other flakes to consume:
- `kits.<name>` — a built **Kit**, ready to `eval`.
- `kitConfigs.<name>` — an evaluated **Kit Config**, ready to use.

A **Kit** being system-agnostic means it is exposed once, not under `forAllSystems`.
Only the **Kit Config**s that need `pkgs` are per-system, since it is their `eval` call that supplies it.

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

## Defining complex **Kit**s

A kit may need more than the default `lib.evalModules` setup, and `newKit` args cover that:
- `customEval` replaces the `evalModules` call each `eval` runs — e.g. to reuse home-manager's module system.
- `exportedToplevelFields` adds extra top-level fields to each **Kit Config**, derived from the evaluated config.

The [`examples/`](examples/) directory holds a complete home-manager-based kit, across [`examples/homekit.nix`](examples/homekit.nix) and its [`examples/flake.nix`](examples/flake.nix):

```nix
kitsys.newKit {
  class = "homeManager";
  lib = hmLib; # home-manager's extended lib (built from the `nixpkgs` input)

  # no base modules of its own: its module system lives in the home-manager repo
  baseModules = [ ];

  # home-manager declares `lib`, `assertions` & `warnings` itself
  declareLibOption = false;
  declareAssertWarnOptions = false;

  # reuse home-manager's module system instead of plain `evalModules`.
  # `pkgs` comes from the eval args, so the kit stays system-agnostic:
  # one kit serves every system, each `eval` call passes `pkgs`.
  customEval = args@{ lib, pkgs, class, modules, ... }:
    lib.evalModules (/* … uses pkgs, hmModules, modulesPath … */);

  # expose home-manager's activation package flat on the Kit Config
  exportedToplevelFields = { config, ... }: {
    inherit (config.home) activationPackage;
  };
}
```

Its flake also builds the resulting home: `nix build ./examples#example-home`.
The kit itself is system-agnostic (it defers `pkgs` to `eval`), so the flake exposes `kits.homekit` once, not per system.

`customEval` must return the raw `evalModules` result, or at least expose `config`, `options` and `extendModules`.
`exportedToplevelFields` receives that same raw result and returns the fields to add.
kitsys re-derives them on every evaluation, including each `extendWith`, so they survive chaining, and it throws if a returned name collides with a top-level option or with `extendWith`.

## How it works

Each `mykit.eval args` call runs the kit's `customEval` — `lib.evalModules` by default — over this module list, in order:
1. the injected kitsys base modules
2. the **Kit** definition's `baseModules`
3. the caller's `configModule` & `moreModules`

A **Kit** injects these base modules by default:
- the `lib` option
- the `assertions` and `warnings` options

Every **Kit Config** also carries `extendWith`, attached as a plain attribute rather than an option, so it never clashes with a kit's own options or their types (such as a strictly-typed `lib`).

`myConfig.extendWith module` calls `prevEval.extendModules` on the recorded evaluation, bumping `_kitState.nestingLevel` and exposing the previous config to the added module as `prevConfig`.

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
| `lib` | `null` | Kit-wide default `lib` for `eval`; a `lib` passed to `eval` takes priority. |
| `declareLibOption` | `true` | Set `false` if `baseModules` declare `lib`. |
| `declareAssertWarnOptions` | `true` | Set `false` if `baseModules` declare these options. |
| `customEval` | wrapper over `lib.evalModules` | Replaces the `evalModules` call each `eval` runs, to reuse another module system. Must return a raw `evalModules` result, or at least expose `config`, `options` and `extendModules`. See [Defining complex **Kit**s](#defining-complex-kits). |
| `exportedToplevelFields` | `_ : {}` | Function adding extra top-level fields to each **Kit Config**, derived from the eval result. See [Defining complex **Kit**s](#defining-complex-kits). |
| `requirePkgs` | `false` | Set `true` for a kit whose modules need `pkgs`: `eval` then throws unless a `pkgs` is passed. |

**Kit** (returned by `kitsys.newKit`):

| Field | Type | Description |
| --- | --- | --- |
| `meta` | attrset | The definition's `meta`. |
| `eval` | function | The kit's evaluation function, derived from the definition. |

**`mykit.eval` args**:

| Arg | Default | Description |
| --- | --- | --- |
| `lib` | `newKit`'s `lib` | The `lib` the evaluation runs with (its `evalModules`, assertion/warning check, and option-default helpers). A value passed here takes priority over `newKit`'s `lib`; `pkgs.lib` is the last resort. Required when neither `pkgs` nor `newKit`'s `lib` is given. |
| `pkgs` | `null` | System-specific `pkgs` for this evaluation. Forwarded to the kit's `customEval`; the default evaluator also injects it as `_module.args.pkgs`. Provides `lib` (as `pkgs.lib`) when no other `lib` is set. |
| `configModule` | required | The module holding the option values to evaluate. |
| `moreModules` | `[]` | Further modules appended after `configModule`. |
| `specialArgs` | `{}` | Extra module args for the evaluation — the place for system-specific inputs such as `pkgs`. |

Any other argument is forwarded to the kit's `customEval` (and from there to `evalModules`), which rejects arguments it does not know.

**Kit Config** (returned by `mykit.eval` / `extendWith`):

| Attr | Description |
| --- | --- |
| `extendWith` | Extend the config with an extra module; returns a new config. |
| `assertions` / `warnings` | Checked at every evaluation and extension. |

Any extra top-level fields the kit's `exportedToplevelFields` returns (such as `activationPackage`) are present too.
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
