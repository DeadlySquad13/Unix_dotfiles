{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cht-sh
  ];
}
