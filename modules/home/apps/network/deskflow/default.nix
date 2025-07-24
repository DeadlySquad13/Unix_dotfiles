{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "network";
  name = "deskflow";
}
{
  home.packages = with pkgs; [
    deskflow
  ];
}
