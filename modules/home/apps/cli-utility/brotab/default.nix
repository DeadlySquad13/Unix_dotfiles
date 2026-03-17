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
  name = "brotab";
}
{
  home.packages = with pkgs; [
   brotab
  ];
}
