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
  name = "nil";
}
{
  home.packages = with pkgs; [
    nil
  ];
}
