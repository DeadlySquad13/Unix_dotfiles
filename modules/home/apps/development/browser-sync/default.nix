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
  name = "browser-sync";
}
{
  home.packages = with pkgs; [
    nodePackages_latest.browser-sync
  ];
}
