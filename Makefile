run-switch: switch optimise garbage-collect-old

switch:
	home-manager switch --flake . --impure --extra-experimental-features 'nix-command flakes' --show-trace

build:
	home-manager build --flake . --impure --extra-experimental-features 'nix-command flakes' --show-trace

darwin-switch:
	nix run nix-darwin -- switch --flake . --impure --show-trace

darwin-build:
	nix run nix-darwin -- build --flake . --impure --show-trace

garbage-collect-old:
	nix-collect-garbage --delete-older-than 10d

garbage-collect:
	nix-collect-garbage

# Saves a little bit of space by hardlinking deps. Judging from logs,
# garbage-collect includes optimise.
optimise:
	nix-store --optimise

# When want to migrate to a newer version of nixpkgs and home-manager.
update:
	nix flake update

edit-vault:
	nix-shell -p sops --run "sops secrets/secrets.yaml"
