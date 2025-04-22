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
  name = "gnumake";
}
{
   environment.systemPackages = with pkgs; [
    gnumake
  ];
}
