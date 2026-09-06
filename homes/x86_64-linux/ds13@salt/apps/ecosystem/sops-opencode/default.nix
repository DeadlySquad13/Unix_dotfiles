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
  ${namespace}.ai-assistance.opencode.mcp = {
    logseqEnvironmentFile = config.sops.templates."logseq-mcp.env".path;
    logseqHost = "salt";

    # The global Logseq agent-namespace ACL data (logseqSharedNamespaces /
    # logseqNamespaceSets / logseqAgentProfiles) is NOT defined here any more:
    # it lives in the shared home module
    # modules/home/apps/ai-assistance/opencode/logseq-profiles.nix (as
    # mkDefault values, so a host could override). This file keeps only the
    # per-host glue: the SOPS secret path and the Logseq API hostname.
    # See docs/guides/logseq-agent-namespaces.md.
  };
}
