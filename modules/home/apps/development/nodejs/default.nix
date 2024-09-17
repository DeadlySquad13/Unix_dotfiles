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
    # pkgs.node-18_x.pkgs.pnpm
    # nodejs_22
    # corepack_22
    nodejs_18
    corepack_18
  ];
}
