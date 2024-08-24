{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "gcalcli";
}
{
  home.packages = with pkgs; [
    gcalcli
  ];
}
