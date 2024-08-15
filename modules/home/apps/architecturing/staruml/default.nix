{ pkgs, ... }:

{
  home.packages = with pkgs; [
    staruml
  ];
}
