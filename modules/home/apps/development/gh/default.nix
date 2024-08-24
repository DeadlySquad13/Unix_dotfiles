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
  name = "gh";
}
{
  home.packages = with pkgs; [
    gh # GitHub Cli.
  ];
}
