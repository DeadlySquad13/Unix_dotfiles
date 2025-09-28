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
  home.packages = with pkgs; [
    ds-omega.gl-ferdium
  ];
}
