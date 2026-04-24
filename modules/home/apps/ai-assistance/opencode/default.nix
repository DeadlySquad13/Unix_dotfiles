{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "ai-assistance";
  name = "opencode";
}
{
  programs.opencode = {
    enable = true;
  };

  # home.file.".aider.conf.yml".source = ./aider.conf.yml;
}
