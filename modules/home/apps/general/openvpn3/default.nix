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
  name = "openvpn3";
}
{
  home.packages = with pkgs; [
    openvpn3
  ];
}
