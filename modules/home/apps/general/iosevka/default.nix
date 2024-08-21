{ pkgs, ... }:

{
  home.packages = with pkgs; [
    iosevka
  ];
}
