# ADR 0004: Per-agent Logseq namespace ACL + OpenCode agent wiring

- Status: Accepted
- Date: 2026-09-06

## Context

OpenCode agents collaborate in a shared Logseq graph through per-agent MCP
gateway containers. OpenCode's own permissions model is tool-name-pattern
based and cannot express namespace granularity, so the namespace ACL must be
enforced at the **process level**: each agent gets its own mcp-logseq instance
whose environment IS its allowed namespaces.

The system must keep each agent's own notes private, share curated trees
between agents, and let agents read "personal" namespaces (everything outside
the agent-defined trees) only where that is granted — without enumerating
personal namespaces. It must also let agents delegate summarization of their
results into a central knowledge base (kbn) without leaking the broad kbn
instance. This ADR records the decisions on the OpenCode/Unix_dotfiles side;
the mcp-logseq side (the ACL contract itself) is recorded in the logseq-mcp
repo ADR `0001-agent-namespace-access-control`.

## Decisions

### 1. Namespace ACL lives in per-agent process env

Each `logseq-<name>` container is a client of the SAME Logseq app; the host
ports are gateway ports, not Logseq instances. Enforcement is the per-process
environment (`LOGSEQ_WRITE_INCLUDES`, `LOGSEQ_INCLUDE_NAMESPACES`,
`LOGSEQ_EXCLUDE_NAMESPACES`) — never a prompt or an agent tool glob.

### 2. Global ACL data lives in a shared module

`modules/home/apps/ai-assistance/opencode/logseq-profiles.nix` owns the GLOBAL
values (`logseqSharedNamespaces`, `logseqNamespaceSets`,
`logseqAgentProfiles`, `logseqSummarizerProfiles`, `logseqSrc`) as `mkDefault`s.
Hosts only keep glue (`logseqEnvironmentFile` in sops, `logseqHost`). This
keeps agent-identity data out of sops-nix and out of any single home.

### 3. "personal" is the complement of agent namespaces — never enumerated

mcp-logseq reserves `personal` as an allow-list marker that matches every page;
paired with `exclude_namespaces` (all other profiles' own trees + unreferenced
bundles) it means *everything outside the agent-defined world*. Profiles opt in
via `writeSets`/`readSets = ["personal"]`; the module derives the excludes.

### 4. Read extends write; writes use their own list

Effective read = `include_namespaces ∪ write_includes` ("read extends write").
Writes gate on `write_includes` (or fall back to include_namespaces), so a
profile can read more than it writes (e.g. plan reads personal but writes only
its own/shared trees).

### 5. Each agent is wired to its own instance only

Top-level `settings.tools."logseq*" = false` disables logseq tools for
everyone; `settings.agent.<name>.tools."logseq-<name>*" = true` re-enables them
for that agent only. There is NO generic `logseq` container server. The legacy
`logseq-mcpo` gateway stays registered for NON-opencode consumers of the shared
MCP stack but is disabled in OpenCode (`settings.mcp."logseq-mcpo".enabled =
false`).

### 6. Tool grants use (legacy) `tools` globs; delegation uses `permission.task`

OpenCode gates subagent invocation via `permission.task`, NOT a tools glob
(v1.2.5 source: last matching rule wins; no match defaults to `ask`; the `task`
tool only hides `deny`ed subagents). Each parent's delegation blocks ONLY the
OTHER agents' counterparts: `permission.task = { "*-kbn" = "deny"; "<agent>-kbn"
= "allow" }`. A blanket `"*" = "deny"` was rejected: it would break the agent's
normal task decomposition via generic subagents (general/explore/…). The `tools`
key (deprecated upstream) is intentionally retained for MCP glob grants because
it cleanly expresses availability per server.

### 7. Result summarization is delegated to hidden `<parent>-kbn` counterparts

Each producing agent (build, plan, nix-build, nix-plan, docs-writer) does not
reach the broad kbn instance. Instead it invokes a hidden subagent
(`mode: subagent`, `hidden: true`, `permission.bash = deny`) that uses a
DEDICATED narrow instance `logseq-summ-<parent>` (ports 18114–18118): WRITE the
parent's own `<parent-own>/_journals` tree (+ shared), READ the parent's own
tree (derived from the profile name). The summarizer profiles are derived in
`logseq-profiles.nix` from the same `agentProfiles` attrset
(`own = "<parent-own>/_journals"`) — no `config` round-trip, so no recursion.
The counterpart's glob is exactly `logseq-summ-<parent>*` — it can neither
read nor write personal namespaces. kbn (the noter) and orchestrator (the
reviewer) have no counterparts.

### 8. Agent tool banks combine rec-inheritance and `baseTools`

The `settings.agent` block restores the readable `rec`-inheritance chain
(build → plan → docs-writer → kbn → orchestrator; nix-build/nix-plan branch
off) for the NON-logseq tool banks, plus flat `baseTools` banks. Isolation
invariant: `logseqGrant` and `permission.task` are applied per-agent at the
leaf and never inherited, so no agent carries another agent's logseq glob.

### 9. The mcp-logseq source is Nix-pinned and mounted, not git-fetched

The supercorp/supergateway:uvx image has uv/python but NO git, so a
`uvx --from git+…` spec fails at container start. The fork is pinned as the
flake input `mcp-logseq` (`flake = false`, rev `aa5550e…`); when `logseqSrc` is
set each logseq container mounts it read-only and runs
`uvx --refresh --from /app/mcp-logseq mcp-logseq` (no git). Logseq containers
are generated from the single `mcpContainers.servers` registry by the composed
Compose generator (see ADR `arion-mcp-architecture.md` and the
`lib/mcp-compose` functions).

### 10. Every change lands in the mcp-logseq check

`checks/mcp-logseq/default.nix` is the static oracle: it forces the real
`mcp.nix` derivation and asserts the 12-server env (7 agent + 5 summarizer),
per-agent glob isolation, the `*-kbn` blocking + own-allow `permission.task`,
counterpart personas, `logseq-mcpo` disabled-in-opencode, the
`personal`/exclude pairing, and that the global values resolve from
`logseq-profiles.nix`. The Makefile targets `mcp-logseq-check` /
`mcp-logseq-debug` correspond to it.

## Consequences

- Adding an agent = define namespace/profile in `logseq-profiles.nix` +
  allocate a port + add persona/tools in `mcp.nix` (see the
  `opencode-agents` skill) + let the check assert it.
- Any change to agent wiring requires `make switch` followed by
  `make mcp-restart` BEFORE starting an OpenCode session, otherwise OpenCode
  does not register the new tools.
- Debugging effective permissions needs no e2e: `opencode debug config` (merged
  config incl. `permission`) and `opencode debug agent <name>` (per-tool
  availability map), plus the static check above.