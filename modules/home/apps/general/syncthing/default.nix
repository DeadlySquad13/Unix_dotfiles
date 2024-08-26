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
  name = "syncthing";
}
{
  home.packages = with pkgs; [
    syncthing
  ];
}
