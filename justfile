nix_system := `nix eval --raw --impure --expr builtins.currentSystem`

_default:
    @just --list

# Run the test suite
test:
	nix eval -f unit-tests/runner.nix
	nix eval ./examples#tests.{{ nix_system }}
