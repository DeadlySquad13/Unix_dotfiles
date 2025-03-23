{
  pkgs-stable,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "logseq";
}
{
  home.packages = with pkgs-stable; [
    logseq
  ];
}
