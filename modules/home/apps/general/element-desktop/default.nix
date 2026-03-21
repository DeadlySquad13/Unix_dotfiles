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
  name = "element-desktop";
}
{
  home.packages = [
    (lib.${namespace}.packageGLify {
      inherit config;
      inherit pkgs;
    } "element-desktop")
  ];
}
