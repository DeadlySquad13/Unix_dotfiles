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
  name = "ferdium";
}
{
  home.packages = [
    (lib.${namespace}.packageGLify {
      inherit config;
      inherit pkgs;
    } "ferdium")
  ];
}
