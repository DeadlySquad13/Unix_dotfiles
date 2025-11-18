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
  name = "musescore";
}
{
  home.packages = [
    (lib.${namespace}.packageGLify {
      inherit config;
      inherit pkgs;
    } "musescore")
  ];
}
