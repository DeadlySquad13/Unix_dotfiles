{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "architecturing";
  name = "archi";
}
{
  home.packages = with pkgs; [
    archi
  ];
}
