{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "misc";
  name = "qmk";
}
{
  home.packages = with pkgs; [
    qmk
  ];
}
