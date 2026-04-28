{
  lib,
  namespace,
  config,
  pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "eog";
  extraPredicate = lib.${namespace}.isLinux;
}
{
  home.packages = with pkgs; [
    eog
  ];
}
