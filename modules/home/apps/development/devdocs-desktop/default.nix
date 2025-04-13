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
  # Available officially only on Linux.
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  home.packages = with pkgs; [
    devdocs-desktop
  ];
}
