{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "architecturing";
  name = "staruml";
}
{
  home.packages = with pkgs; [
    staruml
  ];
}
