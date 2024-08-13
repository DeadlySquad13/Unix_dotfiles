{ pkgs, ... }:

{
  home.packages = with pkgs; [
    numlockx
  ];
}
