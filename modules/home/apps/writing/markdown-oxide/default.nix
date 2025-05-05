{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "writing";
  name = "markdown-oxide";
}
{
  home.packages = with pkgs; [
    markdown-oxide
  ];
}
