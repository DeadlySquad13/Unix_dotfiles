switch:
	home-manager switch --flake . --impure --extra-experimental-features 'nix-command flakes'

build:
	home-manager build --flake . --impure --extra-experimental-features 'nix-command flakes'

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
	# Not sure if it was needed: `nix-channel --update`
