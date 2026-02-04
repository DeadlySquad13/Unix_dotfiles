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
  name = "openvpn3";
}
{
  home.packages = with pkgs; [
    openvpn3
  ];
}
