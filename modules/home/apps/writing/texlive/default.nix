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
  name = "texlive";
}
{
  home.packages = with pkgs; [
    texlive.combined.scheme-full
  ];
}
