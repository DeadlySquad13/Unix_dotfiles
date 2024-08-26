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
  name = "tasksh";
}
{
  home.packages = with pkgs; [
    tasksh
  ];
}
