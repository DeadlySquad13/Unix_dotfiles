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
  extraPredicate = lib.ds-omega.mkIfLinux;
}
{
  home.packages = with pkgs; [
    nmap # Needed for port block tests.
    zapret
  ];
}
