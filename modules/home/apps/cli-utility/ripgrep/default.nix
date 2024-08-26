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
  name = "ripgrep";
}
{
  home.packages = with pkgs; [
    ripgrep
  ];
}
