# Unix dotfiles
To install flake use: `nixos-rebuild switch --flake . --impure`.
For non-NixOs systems, you can do the same thing by substituting `nixos-rebuilt` with `home-manager`:
`home-manager switch --flake . --impure`.

You can specify flake explicitly if you need: `home-manager switch --flake .#<user>@<hostname> --impure`,
for example, `home-manager switch --flake .#ds13@salt --impure`.


This configuration requires some special settings in `nix.conf`. While they're
ensured to be set there automatically, for the first time you may need activate 
special flags manually, specifying them inline in the command:
```nix
home-manager switch --flake . --impure --extra-experimental-features 'nix-command flakes'
```
