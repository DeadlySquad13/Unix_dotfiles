{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Markwhen
    mw
  ];
}
