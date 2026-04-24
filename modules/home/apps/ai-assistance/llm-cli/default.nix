{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "ai-assistance";
  name = "llm-cli";
}
{
  home.packages = with pkgs; [
    llm
  ];
}
