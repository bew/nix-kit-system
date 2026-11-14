# sampleKits/

Sample **Kit**s live here, one file per sample: `sampleKits/<name>.nix`.
Each is exposed by this flake as `sampleKits.<name>`, a factory you call with the inputs it needs.

## Adding a sample kit

Update these places:

- `flake.nix` — expose it as `sampleKits.<name>`, passing the kit's inputs plus `kit-system = self`.
- `examples/flake.nix` — consume it, e.g. as `kits.<name>` and a `kitConfigs` build.
- `examples/` — its example config module and `test.nix` cases, following `homekit.nix`.
- `README.md` — only if the sample needs its own prose; the "Sample **Kit**s" section is generic, so no edit is needed for a new sample.
