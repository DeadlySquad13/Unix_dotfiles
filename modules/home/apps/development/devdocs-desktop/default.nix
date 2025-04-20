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
  # It doesn't build on any of my systems unfortunately. On Darwin it's even
  # marked as deprecated
  extraPredicate = _: false;
}
{
  home.packages = with pkgs; [
    devdocs-desktop
  ];
}
