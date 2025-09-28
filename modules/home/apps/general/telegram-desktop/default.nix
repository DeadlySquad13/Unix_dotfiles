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
  home.packages = [
    (lib.${namespace}.packageGLify {
      inherit config;
      inherit pkgs;
    } "telegram-desktop")
  ];
}
