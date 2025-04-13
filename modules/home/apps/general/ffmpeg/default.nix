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
  name = "ffmpeg";
}
{

  home.packages = with pkgs; [
    ffmpeg_6
  ];
}
