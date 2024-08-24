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
  name = "nvimpager";
}
{
  home.packages = with pkgs; [
    nvimpager
  ];
}
