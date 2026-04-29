{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "development.nix";
  name = "typenix";
}
{
  home.packages = with pkgs; [
    typenix
  ];
}
