{
  lib,
  namespace,
  config,
  inputs,
  pkgs,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "development";
  name = "nodejs";
}
{
  home.packages = with pkgs; [
    # pkgs.node-18_x.pkgs.pnpm
    nodejs_24
    corepack_24
  ];
}
