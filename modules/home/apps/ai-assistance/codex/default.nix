{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ai-assistance";
  name = "codex";
}
{
  home.packages = with pkgs; [
    codex
  ];
}
