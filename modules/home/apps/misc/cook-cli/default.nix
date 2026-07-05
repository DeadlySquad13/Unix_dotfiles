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
  name = "cook-cli";
}
{
  home.packages = with pkgs; [
    cook-cli
  ];
}
