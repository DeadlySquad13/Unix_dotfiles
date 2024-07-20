{ pkgs, ... }:

{
  home.packages = with pkgs; [
    complete-alias
  ];
}
