{
  lib,
  namespace,
  config,
  ...
}:
# INFO: Requires VPN for downloading.
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ai-assistance";
  name = "claude-code";
}
{
  programs.claude-code = {
    enable = true;
  };
}
