{
  lib,
  inputs,
  namespace,
  ...
}: let
  # The agents that PRODUCE results and therefore get a `<parent>-kbn`
  # summarizer counterpart. kbn (the noter) and orchestrator (the reviewer)
  # produce no results, so they get none.
  producingParents = ["build" "plan" "docs-writer" "nix-build" "nix-plan"];

  # Dedicated narrow instances for the `<parent>-kbn` summarizer subagents:
  # WRITE = the parent's OWN `_journals` tree (plus the global shared tree,
  # like every profile). READ is derived from the profile NAME (`summ-<parent>`
  # → the parent's own tree) in mcp.nix, so they can summarize results without
  # ever reaching the broad kbn instance or personal namespaces. Reusing the
  # parent's `own` here (not `config`) keeps this acyclic and decouples it from
  # the module system.
  mkLogseqSummarizerProfile = agent: {
    own = "${agent.own}/_journals";
  };

  agentProfiles = {
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

  summarizerProfiles = lib.mapAttrs' (
    name: agent: lib.nameValuePair "summ-${name}" (mkLogseqSummarizerProfile agent)
  ) (lib.filterAttrs (name: _: builtins.elem name producingParents) agentProfiles);
in {
  # Global Logseq agent-namespace ACL data (per-agent mcp-logseq MCP instances).
  #
  # Distinct from the per-host glue (logseqEnvironmentFile / logseqHost) which
  # stays in the host's sops-opencode module. The namespace VALUES are the
  # "global" part of the ACL model (see docs/guides/logseq-agent-namespaces.md):
  #   - logseqSharedNamespaces : appended to every profile's write list.
  #   - logseqNamespaceSets    : named bundles referenced by writeSets/readSets.
  #   - logseqAgentProfiles    : each profile derives one logseq-<name> server.
  #   - logseqSummarizerProfiles : derived from producingParents' owns (own + "/_journals").
  #   - logseqSrc              : Nix-pinned mcp-logseq source for the containers
  #                              (mounted + `uvx --from`, since the workflow image
  #                              has no git).
  #
  # Values use lib.mkDefault so a host may still override any of them.
  ${namespace}.ai-assistance.opencode.mcp = {
    # Nix-pinned mcp-logseq fork source at the commit the containers install.
    logseqSrc = lib.mkDefault inputs.mcp-logseq;

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

    logseqAgentProfiles = lib.mkDefault agentProfiles;

    # Dedicated narrow instances for the <parent>-kbn summarizer subagents
    # (one per producing parent): WRITE = <parent-own>/_journals (+ the global
    # shared tree), READ = the parent's own tree (derived in mcp.nix from the
    # `summ-<parent>` profile name). They never reach the broad kbn instance
    # or personal namespaces.
    logseqSummarizerProfiles = lib.mkDefault summarizerProfiles;
  };
}