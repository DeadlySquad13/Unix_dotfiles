{ pkgs, ... }:

{
  home.packages = with pkgs; [
    blesh
  ];
}
