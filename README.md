# Unix dotfiles
To install flake use: `nixos-rebuild switch --flake . --impure`.
You can specify flake explicitly if you want: `nixos-rebuild switch --flake .#<user>@<hostname> --impure`,
for example, `nixos-rebuild switch --flake .#ds13@salt --impure`.

This configuration requires some special settings in `nix.conf`. While they're
ensured to be set there automatically, for the first time you may need activate 
special flags manually, specifying them inline in the command:
```nix
nixos-rebuild switch --flake . --impure --extra-experimental-features 'nix-command flakes'
```
