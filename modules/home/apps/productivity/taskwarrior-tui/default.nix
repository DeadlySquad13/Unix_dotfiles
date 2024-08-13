{ pkgs, ... }:

{
  home.packages = with pkgs; [
    taskwarrior-tui
  ];
}
