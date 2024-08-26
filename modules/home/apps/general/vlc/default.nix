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
  name = "vlc";
}
{
  home.packages = with pkgs; [
    vlc
  ];
}
