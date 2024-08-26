{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "ecosystem";
  name = "nurl";
}
{
  home.packages = with pkgs; [
    nurl
  ];
}
