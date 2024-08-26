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
  name = "numlockx";
}
{
  home.packages = with pkgs; [
    numlockx
  ];
}
