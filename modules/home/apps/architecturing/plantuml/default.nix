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
  name = "plantuml";
}
{
  home.packages = with pkgs; [
    # plantuml
    plantuml-c4
  ];
}
