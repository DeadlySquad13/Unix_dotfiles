{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "gnumake";
}
{
  home.packages = with pkgs; [
    gnumake
  ];
}
