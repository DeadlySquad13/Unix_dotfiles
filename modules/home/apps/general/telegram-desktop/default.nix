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
  name = "telegram-desktop";
}
{
  home.packages = with pkgs; [
    ds-omega.gl-telegram-desktop
  ];
}
