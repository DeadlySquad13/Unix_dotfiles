{ pkgs, ... }:

{
  home.packages = with pkgs; [
    tasksh
  ];
}
