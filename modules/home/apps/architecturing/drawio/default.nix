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
  name = "drawio";
}
{
  home.packages = with pkgs; [
    drawio
  ];
}
