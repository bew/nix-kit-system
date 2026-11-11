_default:
    @just --list

# Run the test suite
test:
	nix eval -f tests.nix
