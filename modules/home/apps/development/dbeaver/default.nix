{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "dbeaver";
}
{
  home.packages = with pkgs; [
    dbeaver-bin
  ];
}
