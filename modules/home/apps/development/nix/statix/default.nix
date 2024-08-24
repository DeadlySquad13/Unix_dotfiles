{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development.nix";
  name = "statix";
}
{
  home.packages = with pkgs; [
    statix
  ];
}
