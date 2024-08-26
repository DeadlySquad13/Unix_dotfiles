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
  name = "taskwarrior-tui";
}
{
  home.packages = with pkgs; [
    taskwarrior-tui
  ];
}
