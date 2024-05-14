switch:
	home-manager switch --flake . --impure --extra-experimental-features 'nix-command flakes'

garbage-collect:
	nix-collect-garbage --delete-older-than 10d
