{ pkgs, ... }:

{
  home.packages = with pkgs; [
    glab # GitLab Cli.
  ];
}
