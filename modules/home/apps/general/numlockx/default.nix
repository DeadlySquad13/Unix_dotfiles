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
  extraPredicate = lib.${namespace}.mkIfLinux;
}
{
  home.packages = with pkgs; [
    numlockx
  ];
}
