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

# Virtual Machines
# # Qemu
build-vm-qemu:
	# Delete cached dynamic state of the virtual machine from previous build.
	rm --force nixos.qcow2
	nix-build '<nixpkgs/nixos>' -A vm -I nixpkgs=channel:nixos-24.11 -I nixos-config=./systems/x86_64-vm/simple/default.nix

start-vm-qemu-console:
	QEMU_KERNEL_PARAMS=console=ttyS0 ./result/bin/run-nixos-vm -nographic; reset

# Not recommended: qemu is quite slow when working with graphics.
start-vm-qemu:
	./result/bin/run-nixos-vm

# # VirtualBox
build-vm-qemu:
	nix-build '<nixpkgs/nixos>' -A config.system.build.virtualBoxOVA -I nixpkgs=channel:nixos-24.11 -I nixos-config=./systems/x86_64-vm/vpn/default.nix
