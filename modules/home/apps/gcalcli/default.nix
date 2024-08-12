{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gcalcli
  ];
}
