{ pkgs, ... }:

{
  home.packages = with pkgs; [
    taskwarrior
  ];
}