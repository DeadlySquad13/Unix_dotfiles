{
  lib,
  inputs,
  config ? {},
  namespace ? "ds-omega",
  ...
}: let
  # T1 inner harness provisioner (ADR 0007 D1): the name is namespace-generated
  # as `<spiceNamespace>-inner-conv-plat-prov` from the outer system's
  # `common.spiceNamespace`. The home side may not carry `common`, so fall back
  # to the green default (the check evaluates this module without `config`).
  spiceNamespace = (config.lib.${namespace}.common or {}).spiceNamespace or "darkGreen";
  innerProvisionerAgent = "${spiceNamespace}-inner-conv-plat-prov";

  # Per-agent namespace ACL profiles (one mcp-logseq instance per profile).
  #
  # Model (see docs/adr/0005 and docs/guides/logseq-agent-namespaces.md):
  #   - writeSets / readSets reference named bundles; the reserved `personal`
  #     marker means "everything NOT excluded" (complement) and always pairs
  #     with derived excludes — EXCEPT `readAllNamespaces`, which reads every
  #     page (reserved marker with no excludes; kbn's role).
  #   - `own` trees of non-instance agents (planner/builder) are declared as
  #     named bundles (planOwn / nixPlanOwn / builderOwn / nixBuilderOwn) so
  #     the writing roles (analyst / nix-analyst / reporter) can reference them.
  #
  # "ai Agents_system" (global), "shared-Planner_system" (planPair) and
  # "shared-Builder_system" (buildPair) remain WRITE-accessible to the logseq
  # roles but are intentionally left unused (user decision).
  agentProfiles = {
    orchestrator = {
      own = "ai-orc Orchestrator_system";
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = true; # reads every other profile's own tree
    };
    strategist = {
      own = "ai-str Strategist_system";
      writeSets = ["discovery"]; # publishes validated discovery revisions
      readSets = ["personal" "architecture"];
    };
    tactician = {
      own = "ai-tcn Tactician_system";
      readSets = ["discovery" "architecture"];
      readAllAgentOwns = true; # task-scoped AI reports
    };
    architect = {
      own = "ai-arc Architect_system";
      writeSets = ["architecture"]; # publishes validated ADR/architecture revisions
      readSets = ["discovery" "architecture"];
    };
    researcher = {
      own = "ai-rsh Researcher_system";
      readSets = ["discovery" "architecture"];
    };
    analyst = {
      own = "ai-anl Analyst_system";
      writeSets = ["planOwn" "planPair"]; # populates the planner's own + shared-planner (unused)
      readSets = ["discovery" "architecture"];
    };
    nix-analyst = {
      own = "ai-nxl NixAnalyst_system";
      writeSets = ["nixPlanOwn"]; # populates the nix-planner's own
      readSets = ["discovery" "architecture"];
    };
    reporter = {
      own = "ai-rpt Reporter_system";
      writeSets = ["builderOwn" "nixBuilderOwn" "buildPair"]; # populates builders' own + shared-builder (unused)
      readSets = ["discovery" "architecture"];
    };
    kbn = {
      own = "ai-kbn KnowledgeBaseNoter_system";
      readAllNamespaces = true; # reads every namespace incl. personal (no excludes)
    };
    # T1 inner harness provisioner (ADR 0007 D1): primary, Logseq-producing.
    # Own tree `ai-ihp InnerHarnessProvisioning_system`; reads the shared
    # discovery/architecture trees. Name is namespace-generated (see above).
    "${innerProvisionerAgent}" = {
      own = "ai-ihp InnerHarnessProvisioning_system";
      readSets = ["discovery" "architecture"];
    };
  };

  # The agents that PRODUCE knowledge and therefore get a `<parent>-kbn`
  # summarizer counterpart that journals their changes. A change an agent
  # writes into its own tree is duplicated into the parent's `<own>/_journals`
  # tree as "Updated [[<parent>/page]]" + a simplified copy. kbn (the noter)
  # and orchestrator (the coordinator/status writer) get none; DELIVERY agents
  # (plan / build / nix-plan / nix-build / verifier) have no Logseq access at
  # all, so they get none either.
  producingParents = [
    "strategist"
    "tactician"
    "architect"
    "researcher"
    "analyst"
    "nix-analyst"
    "reporter"
    # T1 inner harness provisioner (ADR 0007 D1) — journals to its own tree and
    # gets a `<name>-kbn` summarizer counterpart.
    innerProvisionerAgent
  ];

  # Dedicated narrow instances for the `<parent>-kbn` summarizer subagents:
  # WRITE = the parent's OWN `_journals` tree (plus the global shared tree,
  # like every profile). READ is derived from the profile NAME (`summ-<parent>`
  # → the parent's own tree) in mcp.nix, so they can journal changes without
  # ever reaching the broad kbn instance or personal namespaces. Reusing the
  # parent's `own` here (not `config`) keeps this acyclic and decoupled from
  # the module system.
  mkLogseqSummarizerProfile = agent: {
    own = "${agent.own}/_journals";
  };

  summarizerProfiles = lib.mapAttrs' (
    name: agent: lib.nameValuePair "summ-${name}" (mkLogseqSummarizerProfile agent)
  ) (lib.filterAttrs (name: _: builtins.elem name producingParents) agentProfiles);

  # ESCALATED write-everywhere instance for the kbn noter: the SAME broad read
  # as `kbn` (readAllNamespaces) plus WRITE across the whole graph
  # (`writeAllNamespaces` ⇒ LOGSEQ_WRITE_INCLUDES collapses to the reserved
  # `personal` complement marker with NO excludes, which subsumes
  # own/shared/sets). Deliberately separate from `logseqAgentProfiles` so the
  # ordinary kbn instance stays write-scoped to its own tree and no other
  # profile's derived includes/excludes change; escalated writes are gated
  # per-tool by an "ask" permission in mcp.nix.
  escalatedProfiles = {
    kbn-escalated = {
      own = "ai-kbn KnowledgeBaseNoter_system";
      readAllNamespaces = true;
      writeAllNamespaces = true;
    };
  };
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
  #   - logseqEscalatedProfiles  : write-everywhere instance for kbn
  #                                (`kbn-escalated`; personal marker, no excludes).
  #   - logseqSrc              : Nix-pinned mcp-logseq source for the containers
  #                              (mounted + `uvx --from`, since the workflow image
  #                              has no git).
  #
  # Values use lib.mkDefault so a host may still override any of them.
  # FIX: Infinite recursion because of namespace
  ds-omega.ai-assistance.opencode.mcp = {
    # Nix-pinned mcp-logseq fork source at the commit the containers install.
    logseqSrc = lib.mkDefault inputs.mcp-logseq;

    # Global shared tree(s): appended to every profile's write list. Kept
    # WRITE-accessible for the logseq-capable roles but intentionally unused.
    logseqSharedNamespaces = lib.mkDefault ["ai Agents_system"];

    # Named namespace bundles referenced by profile writeSets / readSets.
    # "personal" is NOT listed here: it is derived as the complement of the
    # agent-defined namespaces (the reserved `personal` marker in readSets /
    # writeSets grants everything not excluded from that profile).
    logseqNamespaceSets = lib.mkDefault {
      # Own trees of the NON-instance plan/build roles, populated by others.
      planOwn = ["ai-pln Planner_system"]; # written by analyst
      nixPlanOwn = ["ai-nxp NixPlanner_system"]; # written by nix-analyst
      builderOwn = ["ai-bld Builder_system"]; # written by reporter
      nixBuilderOwn = ["ai-nxb NixBuilder_system"]; # written by reporter
      # Shared pair trees (accessible-but-unused per user decision).
      buildPair = ["ai-s-bld shared-Builder_system"];
      planPair = ["ai-s-pln shared-Planner_system"];
      # Shared AI-authored discovery / architecture.
      discovery = ["ai-shared-Discovery_system"];
      architecture = ["ai-shared-Architecture_system"];
    };

    logseqAgentProfiles = lib.mkDefault agentProfiles;

    # Dedicated narrow instances for the `<parent>-kbn` summarizer subagents
    # (one per producing parent): WRITE = <parent-own>/_journals (+ the global
    # shared tree), READ = the parent's own tree (derived in mcp.nix from the
    # `summ-<parent>` profile name). They never reach the broad kbn instance
    # or personal namespaces.
    logseqSummarizerProfiles = lib.mkDefault summarizerProfiles;

    # Escalated, write-everywhere instance for the kbn noter (see above):
    # WRITE = the reserved `personal` complement marker (everything not
    # excluded — and there are NO excludes), READ = every namespace. Kept out
    # of `logseqAgentProfiles` so ordinary profiles' derived ACLs are
    # unaffected; per-tool "ask" permission lives in mcp.nix.
    logseqEscalatedProfiles = lib.mkDefault escalatedProfiles;
  };
}
