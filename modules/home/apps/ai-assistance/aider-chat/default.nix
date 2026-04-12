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
  name = "aider-chat";
}
{
  home.packages = with pkgs; [
    ds-omega-aider-chat
  ];

  home.file.".aider.conf.yml".source = ./aider.conf.yml;
}
