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
  extraPredicate = lib.${namespace}.isLinux;
}
{
  home.packages = with pkgs; [
    numlockx
  ];
}
