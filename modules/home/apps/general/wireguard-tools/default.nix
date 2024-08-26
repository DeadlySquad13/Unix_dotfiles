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
  name = "wireguard-tools";
}
{
  home.packages = with pkgs; [
    wireguard-tools
  ];
}
