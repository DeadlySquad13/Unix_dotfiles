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
}
{
  home.packages = with pkgs; [
    eog
  ];
}
