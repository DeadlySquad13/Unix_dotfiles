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
  name = "zapret";
  extraPredicate = lib.ds-omega.isLinux;
}
{
  home.packages = with pkgs; [
    nmap # Needed for port block tests.
    zapret
  ];
}
