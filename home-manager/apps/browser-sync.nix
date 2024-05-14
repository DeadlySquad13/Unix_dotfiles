{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodePackages_latest.browser-sync
  ];
}
