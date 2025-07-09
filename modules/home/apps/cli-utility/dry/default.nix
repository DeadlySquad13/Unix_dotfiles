{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  # Docker tui aka `docker ps`.
  name = "dry";
}
{
  home.packages = with pkgs; [
    dry
  ];
}
