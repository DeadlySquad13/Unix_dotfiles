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
  name = "gpick";
}
{

  home.packages = with pkgs; [
    gpick
  ];
}
