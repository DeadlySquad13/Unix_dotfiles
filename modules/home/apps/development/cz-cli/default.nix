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
  name = "cz-cli";
}
{
  home.packages = with pkgs; [
    cz-cli
  ];
}
