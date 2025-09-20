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
  name = "zapret";
}
{
  home.packages = with pkgs; [
    nmap # Needed for port block tests.
    zapret
  ];
}
