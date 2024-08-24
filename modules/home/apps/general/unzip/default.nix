{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "unzip";
}
{
  home.packages = with pkgs; [
    unzip
  ];
}
