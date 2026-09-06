{
  lib,
  namespace,
  ...
}: {
  # Global Logseq agent-namespace ACL data (per-agent mcp-logseq MCP instances).
  #
  # Distinct from the per-host glue (logseqEnvironmentFile / logseqHost) which
  # stays in the host's sops-opencode module. The namespace VALUES are the
  # "global" part of the ACL model (see docs/guides/logseq-agent-namespaces.md):
  #   - logseqSharedNamespaces : appended to every profile's write list.
  #   - logseqNamespaceSets    : named bundles referenced by writeSets/readSets.
  #   - logseqAgentProfiles    : each profile derives one logseq-<name> server.
  #
  # Values use lib.mkDefault so a host may still override any of them.
  ${namespace}.ai-assistance.opencode.mcp = {
    # Global shared tree(s): appended to every profile's write list.
    logseqSharedNamespaces = lib.mkDefault ["ai Agents_system"];

    # Named namespace bundles referenced by profile writeSets / readSets.
    # "personal" is NOT listed here: it is derived as the complement of the
    # agent-defined namespaces (the reserved `personal` marker in readSets /
    # writeSets grants everything not excluded from that profile).
    logseqNamespaceSets = lib.mkDefault {
      # Shared between build and nix-build.
      buildPair = ["ai-s-bld shared-Builder_system"];
      # Shared between plan, nix-plan and kbn.
      planPair = ["ai-s-pln shared-Planner_system"];
    };

    logseqAgentProfiles = lib.mkDefault {
      kbn = {
        own = "ai-kbn KnowledgeBaseNoter_system";
        writeSets = ["planPair" "personal"];
      };
      build = {
        own = "ai-bld Builder_system";
        writeSets = ["buildPair"];
      };
      plan = {
        own = "ai-pln Planner_system";
        writeSets = ["planPair"];
        readSets = ["personal"];
      };
      docs-writer = {
        # The profile table the user supplied omitted docs-writer — keep or drop.
        own = "ai-dwt DocsWriter_system";
      };
      nix-build = {
        own = "ai-nxb NixBuilder_system";
        writeSets = ["buildPair"];
      };
      nix-plan = {
        own = "ai-nxp NixPlanner_system";
        writeSets = ["planPair"];
        readSets = ["personal"];
      };
      orchestrator = {
        own = "ai-orc Orchestrator_system";
        readAllAgentOwns = true; # reads every other profile's own tree
      };
    };
  };
}