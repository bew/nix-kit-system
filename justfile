_default:
    @just --list

# Run the test suite
test:
	nix eval -f unit-tests/runner.nix
