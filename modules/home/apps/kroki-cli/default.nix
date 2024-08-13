{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ds-omega.kroki-cli
  ];
}
