{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "obsidian";
}
{
  home.packages = with pkgs; [
    obsidian
  ];
}
