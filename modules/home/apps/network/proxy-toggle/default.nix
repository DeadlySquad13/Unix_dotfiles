{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "network";
  name = "proxy-toggle";
}
{
  home.packages = with pkgs; [
    ds-omega.proxy-toggle
  ];
}
