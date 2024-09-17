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
  name = "iosevka";
}
{
  home.packages = with pkgs; [
    iosevka
  ];
}
