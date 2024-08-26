{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "architecturing";
  name = "mw";
}
{
  home.packages = with pkgs; [
    # Markwhen
    mw
  ];
}
