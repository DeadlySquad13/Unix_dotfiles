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
  name = "go";
}
{
  home.packages = with pkgs; [
    go
  ];
}
