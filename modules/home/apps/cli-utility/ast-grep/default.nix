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
  name = "ast-grep";
}
{
  home.packages = with pkgs; [
    ast-grep
  ];
}
