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
  name = "blesh";
}
{
  home.packages = with pkgs; [
    blesh
  ];
}
