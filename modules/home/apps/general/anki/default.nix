{
  lib,
  namespace,
  config,
  pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "general";
  name = "anki";
}
{
  home.packages = [
    (lib.${namespace}.packageGLify {
      inherit config;
      inherit pkgs;
    } "anki")
  ];
}
