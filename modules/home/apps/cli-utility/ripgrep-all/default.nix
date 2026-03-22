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
  name = "ripgrep-all";
}
{
  home.packages = with pkgs; [
    ripgrep-all
  ];
}
