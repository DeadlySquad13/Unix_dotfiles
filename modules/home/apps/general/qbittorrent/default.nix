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
  name = "qbittorrent";
}
{
  home.packages = with pkgs; [
    qbittorrent
  ];
}
