{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "deno";
}
{
  home.packages = with pkgs; [
    deno
  ];
}
