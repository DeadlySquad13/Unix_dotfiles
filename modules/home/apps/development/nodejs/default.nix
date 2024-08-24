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
  name = "nodejs";
}
{
  home.packages = with pkgs; [
    nodejs_22
    # pkgs.node-18_x.pkgs.pnpm
    corepack_22
  ];
}
