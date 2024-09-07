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
  name = "alejandra";
}
{
  home.packages = with pkgs; [
    alejandra
  ];
}
