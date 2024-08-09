{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gh # GitHub Cli.
  ];
}
