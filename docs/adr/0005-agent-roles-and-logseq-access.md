# ADR 0005: Agent roles and Logseq access (knowledge roles vs DELIVERY agents)

- Status: Accepted
- Date: 2026-09-07
- Amended: 2026-09-08 (ask-gated cross-namespace writes; built-in `plan` as a main agent)
- Supersedes: the agent model of [ADR 0004](0004-logseq-agent-namespaces.md)

## Context

ADR 0004 established the per-agent mcp-logseq gateway model: one lightweight
container per agent profile whose process environment IS the namespace ACL.
The rework recorded here changes **who has Logseq and for what**. The old model
gave the *delivery* producers (`build`, `plan`, `nix-build`, `nix-plan`,
`docs-writer`) their own instances and `<parent>-kbn` summarizer counterparts,
on top of the knowledge roles.

The implemented model (authoritative: `logseq-profiles.nix`, `mcp.nix`, and
the `checks/mcp-logseq` static oracle) splits agents into two classes:

- **Knowledge roles** — nine roles that reason over the graph. Each owns a
  per-agent `logseq-<role>` instance; most delegate journaling of their own
  changes to a hidden `<parent>-kbn` summarizer counterpart.
- **DELIVERY agents** — `plan`, `nix-plan`, `build`, `nix-build`, `verifier`.
  They execute work and have **no Logseq at all**: no server, no `logseq-*`
  tools glob, no namespace credentials. Their result trees still exist in the
  graph but are written *for* them by the knowledge roles.

The per-process ACL machinery that is still true is carried forward unchanged
from ADR 0004 (per-process env ACL, the `personal` complement marker, no
generic `logseq` server, `logseq-mcpo` disabled in OpenCode only, the
Nix-pinned mcp-logseq source, `permission.task` semantics, and the static
check).

The 2026-09-08 amendment addresses two gaps in that model (decisions 10–11
below; implemented in the Opencode AI-assistance config module,
`modules/home/apps/ai-assistance/opencode/logseq-profiles.nix`). First, the
per-process env ACL is a **hard block**: `kbn` could not write any namespace
beyond its own tree + the global shared tree even when the human explicitly
requested and approved a precise change (e.g., marking a task DONE in the
personal journal `2026.09.08`) — an interactive approval cannot override a
process credential, so explicit approval had no effect on writes. Second, the
built-in `plan` agent was invocable only as a subagent, never as a main
session agent.

## Decisions

### 1. Two agent classes: knowledge roles and DELIVERY agents

- **Knowledge roles** (logseq-capable): `orchestrator`, `strategist`,
  `tactician`, `architect`, `researcher`, `analyst`, `nix-analyst`,
  `reporter`, `kbn`. Each derives one `logseq-<role>` gateway from its
  profile in `logseq-profiles.nix`.
- **DELIVERY agents** (no Logseq): `plan`, `nix-plan`, `build`, `nix-build`,
  `verifier`. They are configured with the `delivery` / `deliveryNix` tool
  banks only and are deliberately granted **no `logseq-*` glob**, no server and
  no credentials. They never mount Logseq into their context.
- `coding` and `prompt-designer` remain Logseq-less authoring personas.

### 2. Nine knowledge-role profiles, each with its own `logseq-<name>` instance

Each profile is `own` + `writeSets` + `readSets` (+ the boolean modifiers
`readAllAgentOwns` / `readAllNamespaces`). The derived env per instance:

- `LOGSEQ_WRITE_INCLUDES` = `own` ++ global shared (`ai Agents_system`) ++
  resolved `writeSets`.
- `LOGSEQ_INCLUDE_NAMESPACES` = resolved `readSets`, plus every OTHER profile's
  own tree when `readAllAgentOwns`, plus the `personal` marker when
  `readAllNamespaces`. Effective read = write ∪ include ("read extends write").
- `LOGSEQ_EXCLUDE_NAMESPACES` is derived **only** when the profile uses the
  `personal` marker (all other owns + unreferenced set bundles); a
  `readAllNamespaces` profile is the deliberate exception and has none.

The implemented profiles (ports are the allocated gateway ports; `shared` =
the global `ai Agents_system`, appended to every write list):

| role | mode | port | own tree | writes beyond own + shared | reads beyond its write list |
| --- | --- | --- | --- | --- | --- |
| orchestrator | primary | 18113 | `ai-orc Orchestrator_system` | — | discovery, architecture, every other profile's own (`readAllAgentOwns`) |
| strategist | primary | 18108 | `ai-str Strategist_system` | discovery | `personal`, architecture |
| tactician | subagent | 18109 | `ai-tcn Tactician_system` | — | discovery, architecture, every other profile's own (`readAllAgentOwns`) |
| architect | subagent | 18110 | `ai-arc Architect_system` | architecture | discovery, architecture |
| researcher | subagent | 18111 | `ai-rsh Researcher_system` | — | discovery, architecture |
| analyst | subagent | 18112 | `ai-anl Analyst_system` | `planOwn`, `planPair` | discovery, architecture |
| nix-analyst | subagent | 18114 | `ai-nxl NixAnalyst_system` | `nixPlanOwn` | discovery, architecture |
| reporter | subagent | 18115 | `ai-rpt Reporter_system` | `builderOwn`, `nixBuilderOwn`, `buildPair` | discovery, architecture |
| kbn | all | 18103 | `ai-kbn KnowledgeBaseNoter_system` | — | **whole graph** (`readAllNamespaces`) |
| kbn (escalated) | all | 18123 | `ai-kbn KnowledgeBaseNoter_system` | **whole graph** (`writeAllNamespaces`; every write `ask`-gated — decision 10) | — |

The `kbn-escalated` row is not a tenth role: it is kbn's second, write-everywhere
gateway (same agent, same own tree; `logseqEscalatedProfiles` in
`logseq-profiles.nix`), kept separate so no other profile's derived ACL changes.

### 3. DELIVERY namespaces are named bundles, populated by the roles

The planner/builder trees exist as graph namespaces but their owning agents
have no Logseq, so the trees are declared as **named namespace bundles**
(`logseqNamespaceSets`) that the writing roles reference:

- `planOwn` = `ai-pln Planner_system` — written by **analyst**.
- `nixPlanOwn` = `ai-nxp NixPlanner_system` — written by **nix-analyst**.
- `builderOwn` = `ai-bld Builder_system`, `nixBuilderOwn` =
  `ai-nxb NixBuilder_system` — written by **reporter**.
- `planPair` = `ai-s-pln shared-Planner_system` and `buildPair` =
  `ai-s-bld shared-Builder_system` remain write-accessible but intentionally
  unused.

`plan` / `nix-plan` / `build` / `nix-build` / `verifier` therefore never write
their own namespaces; the knowledge roles populate them from manifests and
results.

### 4. Shared trees: `discovery`/`architecture` are the ACTIVE shared trees

The global `ai Agents_system` plus the `planPair`/`buildPair` pair trees stay
**write-accessible to every logseq-capable role but intentionally left unused**
(user decision). The active shared collaboration trees are:

- `discovery` = `ai-shared-Discovery_system` — published by **strategist**
  (writeSets) after validating discovery revisions; read by most roles.
- `architecture` = `ai-shared-Architecture_system` — published by **architect**
  (writeSets); read by most roles.

### 5. `kbn` is the ONLY whole-graph reader and the only `/kbn`-vault agent

`kbn` uses the reserved `readAllNamespaces` flag: the `personal` marker appears
in its include list with **NO excludes** (`LOGSEQ_EXCLUDE_NAMESPACES` absent) —
the deliberate exception to the rule that `personal` always pairs with derived
excludes. `kbn` is also the only agent granted the `filesystem*` MCP bank (the
`/kbn` vault mount). Every other profile that may read "personal" is a
derived-complement reader with excludes. Its *writes* stay own + shared by
default; cross-namespace writes become possible only behind an explicit `ask`
approval (decision 10).

### 6. Journaling is delegated to hidden `<parent>-kbn` summarizers — knowledge roles only

The producing knowledge roles each delegate journaling of a change they wrote
into their own tree to a hidden `<parent>-kbn` counterpart:

- Counterpart agents: `strategist-kbn`, `tactician-kbn`, `architect-kbn`,
  `researcher-kbn`, `analyst-kbn`, `nix-analyst-kbn`, `reporter-kbn`
  (`mode: subagent`, `hidden: true`, `permission.bash = deny`).
- Each uses a **dedicated, narrow instance** `logseq-summ-<parent>` (ports
  18116–18122) whose ACL is: WRITE the parent's own `<parent-own>/_journals`
  tree (+ the global shared tree); READ the parent's own tree only. Grant glob
  is exactly `{logseq-summ-<parent>*}` — never the broad `logseq-kbn*` instance
  (which may reach personal/shared) and never the parent's own instance.
- Their job is to journal a change the parent wrote: `Updated
  [[<parent> page]]` + a simplified copy.
- `kbn` (the noter) and `orchestrator` (the coordinator/status writer) get **no
  counterpart**; DELIVERY agents have no Logseq so they get none either.
- Summarizer profiles are derived in `logseq-profiles.nix` from the same
  `agentProfiles` attrset (`own = "<parent-own>/_journals"`, reuse of the
  parent's `own`, not `config`) — acyclic, no module-system round-trip.

### 7. Delegation rule is unchanged but applies to the producing knowledge roles

Each producing parent's subagent invocation is gated by
`permission.task = { "*-kbn" = "deny"; "<parent>-kbn" = "allow" }`. The blanket
`"*" = "deny"` remains rejected (it would break normal task decomposition via
generic subagents); `tools`-glob denial cannot gate the `task` tool. Evaluation
remains last-match-wins with a default of `ask`, and the `task` tool only hides
`deny`ed subagents.

### 8. Tool grants: flat banks + `logseq-<role>*` globs (carried forward)

- Top-level `settings.tools."logseq*" = false` disables Logseq tools for
  everyone; `settings.agent.<name>.tools."logseq-<name>*" = true` re-enables
  them for that agent only. The `tools` key (deprecated upstream) is retained
  for these MCP glob grants; delegation is a separate `permission.task` concern.
- Knowledge roles carry the shared `knowledge` bank (`time*`, `memory*`,
  `fetch*`, `ddg-search*`) plus exactly their own `logseq-<role>*` glob;
  `kbn` additionally gets `filesystem*` (`/kbn` vault); `nix-analyst`
  additionally gets `nixos*`.
- DELIVERY agents carry the `delivery` / `deliveryNix` banks only — no
  `logseq-*` glob at all.

### 9. Retained machinery from ADR 0004

- Single Logseq app; host ports are gateway ports; the per-process env is the
  ACL.
- No generic `logseq` server; `logseq-mcpo` stays registered for non-opencode
  consumers but is `.enabled = false` in OpenCode.
- mcp-logseq source is Nix-pinned (flake input `mcp-logseq`, rev
  `aa5550e64d8486ee8329ee9320fc82452e4eb0c2`), mounted read-only into each
  logseq container and run via `uvx --refresh --from /app/mcp-logseq
  mcp-logseq` (the `supercorp/supergateway:uvx` image has no git).
- The static oracle at `checks/mcp-logseq/default.nix` asserts the **17-server
  env** (9 knowledge-role + the `kbn-escalated` write-everywhere instance +
  7 `logseq-summ-<parent>` instances), per-agent glob
  isolation, DELIVERY agents carrying no logseq glob, the `*-kbn` deny +
  own-allow `permission.task`, counterpart personas, `logseq-mcpo` disabled in
  OpenCode, the `personal`/exclude pairing, the kbn `readAllNamespaces`
  exception, the `logseq-kbn-escalated_*` ask gate, and that the global values
  resolve from `logseq-profiles.nix`.

### 10. Cross-namespace writes are ask-gated, not hard-blocked (`kbn`)

- **Problem.** The env-ACL model made approval meaningless for writes: `kbn`
  was hard-blocked from writing anything outside
  `ai-kbn KnowledgeBaseNoter_system` + the global shared tree, even when the
  user explicitly requested and approved the exact change (marking a task DONE
  in the personal journal `2026.09.08`). An interactive "yes" cannot override
  a process credential.
- **Decision.** `kbn` gains an **ask-gated write complement**: its instance's
  env ACL is widened beyond own + shared (capability), and authorization moves
  up into OpenCode's `ask` permission flow over the `logseq-kbn*` glob — every
  write outside the default write set surfaces an approval prompt and executes
  **only** on explicit user approval. Denying (or ignoring) the prompt fails
  closed: nothing is written.
- **Why this fits the model.** OpenCode's tool-pattern permissions cannot
  express namespace granularity (the reason ADR 0004 moved the ACL into the
  process env) — but a human approval CAN: the approver sees the exact target
  page/namespace at prompt time. The widened env supplies capability; the
  per-operation human decision supplies the namespace-granular authorization
  the pattern model lacks.
- **Default unchanged.** Deny-by-default is preserved: absent an approval,
  `kbn` writes only its own namespace + shared, exactly as before. The widened
  reach is capability, not authorization. Least privilege / fail-safe default
  stays intact.
- **Scope.** Introduced for `kbn` (the whole-graph noter) only; every other
  role keeps its exact hard write set, and `kbn`'s read scope (decision 5) is
  unchanged. Approved writes may reach any namespace, **including personal
  ones** (the `personal` complement — deliberately never enumerated,
  decision 2).
- **Rejected alternatives.** (a) *Keep the hard block* — there is no path for
  legitimate, human-approved corrections to personal data; the
  "approved-yet-blocked" paradox erodes trust in the permission model and
  forces manual edits outside the agent. (b) *Per-namespace static ACLs*
  (enumerate the target namespaces in `kbn`'s write list) — still
  unconditional: once listed, writes flow without per-operation oversight,
  and enumerating "personal" contradicts the complement-marker design. The
  ask-based flow was chosen because it keeps the fail-safe default while
  making the human decision the actual authorization, applied per operation.

### 11. The built-in `plan` agent becomes available as a main agent

- `plan` remains a **DELIVERY** agent in every other respect (decision 1): no
  Logseq, no `logseq-*` glob, no credentials; its namespace (`planOwn`) is
  still populated by **analyst** (decision 3).
- What changes is only the invocation mode: `plan` becomes selectable as a
  **main** (top-level session) agent while remaining delegable as a subagent.
  Previously it could only be invoked as a subagent of a parent
  (orchestrator/tactician).
- Rationale: the user sometimes wants to plan directly at top level — without
  a parent first selecting delivery — while keeping `plan`'s read-only
  guardrails (its persona already denies `edit` and restricts `bash` to
  `ask`).
- The two-class model is unchanged: `plan` does not become a knowledge role
  and gains no graph access.

## Consequences

- Adding an agent that reasons over the graph = a knowledge-role profile in
  `logseq-profiles.nix` + port in `mcp.nix` + persona/tools in `mcp.nix`
  (see the `opencode-agents` skill) + let the check assert it. Adding a
  DELIVERY agent = banks only, no Logseq wiring, no profile.
- Any change to agent wiring requires `make switch` followed by
  `make mcp-restart` BEFORE starting an OpenCode session, otherwise OpenCode
  does not register the new tools.
- Debugging effective permissions needs no e2e: `opencode debug config` (merged
  config incl. `permission`) and `opencode debug agent <name>` (per-tool
  availability map), plus `make mcp-logseq-check` / `make mcp-logseq-debug`.
- Cross-namespace writes are possible for `kbn` **only behind an explicit
  per-operation approval**: every such write is preceded by an `ask` prompt in
  the session, so the session transcript doubles as the audit trail of which
  writes were human-approved (vs. the old model, where a write was either
  impossible or unconditionally pre-authorized).
- Human-approved writes can touch **personal data** (e.g., journal task
  states). Treat `ask` prompts on `logseq-kbn*` as the authorization boundary:
  after this change, a successful cross-namespace write is evidence of an
  approval, not of a misconfiguration — the env ACL alone no longer proves
  authorization.
- The amendment has landed in `logseq-profiles.nix`: the static oracle
  (`checks/mcp-logseq`) asserts the `kbn-escalated` write-everywhere env + the
  `ask` permission glue, and the decision-2 profile table gained a separate
  `kbn-escalated` row — a second escalated instance, so `kbn`'s default row
  (writes stay own + shared) is unchanged. The existing re-registration rule
  above (`make switch` + `make mcp-restart`) applies unchanged.
