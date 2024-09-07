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
  name = "tree";
}
{
  home.packages = with pkgs; [
    tree
  ];
}
