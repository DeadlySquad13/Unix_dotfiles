{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "imagemagick";
}
{

  home.packages = with pkgs; [
    imagemagick
  ];
}
