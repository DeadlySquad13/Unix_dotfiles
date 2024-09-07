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
  name = "devdocs-desktop";
}
{
  home.packages = with pkgs; [
    devdocs-desktop
  ];
}
