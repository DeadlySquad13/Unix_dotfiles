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
  name = "zathura";
}
{
  home.packages = with pkgs; [
    zathura
  ];
}
