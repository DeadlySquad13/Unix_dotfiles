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
  name = "keepassxc";
}
{
  home.packages = with pkgs; [
    keepassxc
  ];
}
