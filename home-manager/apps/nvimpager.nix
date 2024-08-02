{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nvimpager
  ];
}
