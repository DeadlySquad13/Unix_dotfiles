{
  lib,
  namespace,
  config,
  pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "swi-prolog";
}
{

  home.packages = with pkgs; [
    swi-prolog
  ];
}
