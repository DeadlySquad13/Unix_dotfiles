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
  name = "undollar";
}
{
  home.packages = with pkgs; [
    undollar
  ];
}
