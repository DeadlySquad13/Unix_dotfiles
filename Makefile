run-switch: switch optimise garbage-collect-old

switch:
	home-manager switch --flake . --impure --extra-experimental-features 'nix-command flakes' --show-trace

build:
	home-manager build --flake . --impure --extra-experimental-features 'nix-command flakes' --show-trace

deploy-dry:
	nix run github:serokell/deploy-rs -- --dry-activate -- .#cake --impure --extra-experimental-features 'nix-command flakes' --show-trace

deploy-with-activate:
	mkdir -p ./logs
	nix run github:serokell/deploy-rs -- --log-dir ./logs -- .#cake --impure --extra-experimental-features 'nix-command flakes' --show-trace

deploy: deploy-dry deploy-activate

switch-system:
	sudo nixos-rebuild switch --flake .#olivier --impure

build-system:
	sudo nixos-rebuild build --flake .#olivier --impure --show-trace

switch-darwin:
	nix run nix-darwin -- switch --flake . --impure

build-darwin:
	nix run nix-darwin -- build --flake . --impure --show-trace

check:
	nix flake check

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
