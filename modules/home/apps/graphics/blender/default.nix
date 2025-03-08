{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "graphics";
  name = "blender";
}
{
  home.packages = with pkgs; [
    ds-omega.gl-blender
  ];
}
