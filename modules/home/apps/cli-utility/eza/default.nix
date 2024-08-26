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
  name = "eza";
}
{
  home.packages = with pkgs; [
    eza
  ];

  home.shellAliases = {
    ll = "eza -lagh --time-style=long-iso --group-directories-first --icons";
  };
}
