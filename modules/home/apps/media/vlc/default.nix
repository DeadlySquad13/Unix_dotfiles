{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "media";
  name = "vlc";
}
{
  home.packages = with pkgs; [
    vlc
  ];
}
