{ pkgs, ... }:

{
  home.packages = with pkgs; [
    yed
  ];
  imports = [
    ./java-fonts-fix.nix
  ];
}
