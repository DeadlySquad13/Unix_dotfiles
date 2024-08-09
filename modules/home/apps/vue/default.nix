{ pkgs, ... }:

{
  home.packages = with pkgs; [
    vue
  ];
  imports = [
    ../java-fonts-fix/default.nix
  ];
}
