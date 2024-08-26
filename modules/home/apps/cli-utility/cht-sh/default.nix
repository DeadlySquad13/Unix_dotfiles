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
  name = "cht-sh";
}
{
  home.packages = with pkgs; [
    cht-sh
  ];
}
