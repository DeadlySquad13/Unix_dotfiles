{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops-opencode";
}
{
  ${namespace}.ai-assistance.opencode.mcp.logseqEnvironmentFile =
    config.sops.templates."logseq-mcp.env".path;
}
