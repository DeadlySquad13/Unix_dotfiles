{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "architecturing";
  name = "inkscape";
}
{
  home.packages = with pkgs; [
    inkscape
  ];
}
