{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "glab";
}
{
  home.packages = with pkgs; [
    glab # GitLab Cli.
  ];
}
