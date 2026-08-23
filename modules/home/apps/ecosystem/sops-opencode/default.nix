{
  config,
  lib,
  namespace,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops-opencode";
}
{
  sops = {
    secrets = {
      logseq_api_token = {};
    };
    templates = {
      "logseq-mcp.env".content = ''
        LOGSEQ_API_TOKEN=${config.sops.placeholder.logseq_api_token}
      '';
    };
  };
}
