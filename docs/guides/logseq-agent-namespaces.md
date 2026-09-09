# Logseq agent-namespace profiles (per-agent MCP instances)

This guide defines how the per-agent Logseq restriction is configured for the
OpenCode agent fleet. It explains the model, how OpenCode is wired to it, and
why the namespace ACL lives in a per-agent process rather than in OpenCode's
own permissions model. The operative decision record is
[ADR 0005](../../docs/adr/0005-agent-roles-and-logseq-access.md), which
supersedes ADR 0004's agent model.

## Model at a glance

One Logseq **app** serves the whole system. There is exactly one Logseq HTTP
API (`LOGSEQ_API_URL`, port 12315) and one SOPS token file. The per-agent
restriction is implemented by running **one lightweight MCP gateway container
per agent profile** — each wraps a single `mcp-logseq` Python process whose
**environment IS the namespace ACL**:

- `LOGSEQ_WRITE_INCLUDES` — namespaces the process may WRITE (allow-list).
- `LOGSEQ_INCLUDE_NAMESPACES` — READ allow-list for namespaces beyond the
  write list; the effective read list is `include ∪ write` ("read extends
  write", so writable namespaces are always readable).
- `LOGSEQ_EXCLUDE_NAMESPACES` — deny-list carved out of an allow-list (exclude
  wins). Required whenever the reserved `personal` marker is used (below),
  except for the whole-graph profiles (`readAllNamespaces` kbn and
  `writeAllNamespaces` kbn-escalated).

All gateway containers point at the same Logseq API with the same token. The
host ports (`18103` for `logseq-kbn`, `18108`–`18115` for the knowledge-role
instances, `18123` for the `kbn-escalated` write-everywhere instance,
`18116`–`18122` for the summarizer instances) are gateway ports,
**not Logseq instances** — Logseq remains exactly one app.

Agents fall into two classes (see below): **knowledge roles**, each wired to
its own `logseq-<role>` instance, and **DELIVERY agents**, which have no Logseq
at all.

## Why the ACL lives in the process env, not in OpenCode

OpenCode's permissions/tools model is **tool-name-pattern based**. It can
enable/disable whole tools per agent (e.g. `"logseq-reporter*"`), but it cannot
express *"this agent may only write namespace `ai-anl Analyst_system`"* — that
is a constraint on tool **arguments** (the page title), which OpenCode does not
inspect. So the hard namespace ACL is enforced by the per-agent mcp-logseq
process, and OpenCode's per-agent `tools` globs are only the **wiring** that
exposes each instance to its owner.

## Roles: knowledge roles vs DELIVERY agents

The model is role-based, not producer-based:

- **Knowledge roles** (logseq-capable) — `orchestrator`, `strategist`,
  `tactician`, `architect`, `researcher`, `analyst`, `nix-analyst`,
  `reporter`, `kbn`. Each derives exactly one `logseq-<role>` gateway from its
  profile (kbn additionally gets the escalated `kbn-escalated` write-everywhere
  instance — see below).
- **DELIVERY agents** — `plan`, `nix-plan`, `build`, `nix-build`, `verifier`.
  They execute work and get **no Logseq at all**: no server, no `logseq-*`
  tools glob, no namespace credentials. Their own result trees
  (`ai-pln Planner_system`, `ai-nxp NixPlanner_system`, `ai-bld
  Builder_system`, `ai-nxb NixBuilder_system`) exist in the graph but are
  **populated for them** by the knowledge roles (analyst, nix-analyst,
  reporter) — see [Delivery namespaces](#delivery-namespaces-populated-by-roles).
- `coding` and `prompt-designer` are kept as authoring personas with no Logseq.

## Namespace model

- **own** — the role's dedicated top-level namespace (e.g.
  `ai-anl Analyst_system` for `analyst`, `ai-orc Orchestrator_system` for
  `orchestrator`). Everything under it is the role's own notes.
- **shared** — the global `ai Agents_system` tree is appended to EVERY
  profile's write list (`logseqSharedNamespaces`). Together with the pair trees
  it is write-accessible to all logseq-capable roles but **intentionally left
  unused**; the ACTIVE shared trees are `discovery` and `architecture` (below).
- **discovery / architecture** — the active shared collaboration trees,
  declared as bundles in `logseqNamespaceSets`:
  `discovery` = `ai-shared-Discovery_system` (published by **strategist**),
  `architecture` = `ai-shared-Architecture_system` (published by
  **architect**). Most roles read both.
- **personal** — DERIVED, not enumerated: every namespace that is *not* under
  an agent-defined namespace (role `own` trees and their set bundles). A
  profile opts in with the reserved marker `personal` in its `readSets` /
  `writeSets`; the module derives `exclude_namespaces` = all other roles' own
  trees + set bundles the profile does not reference. E.g. with analyst's own
  = `ai-anl Analyst_system`, `[[ai-anl Analyst_system]]` and
  `[[ai-anl Analyst_system/AiAssistance]]` are analyst's own notes, while
  `[[AiAssistance]]`, `[[rut Rutube_system/AiAssistance]]` are personal.
- **`readAllNamespaces` (kbn only)** — the reserved `personal` marker with **NO
  excludes**: kbn is the sole whole-graph reader (see below). It is the
  deliberate exception to the rule that `personal` pairs with derived excludes.
- **`writeAllNamespaces` (`kbn-escalated` only)** — the same complement marker,
  but in the WRITE list: `LOGSEQ_WRITE_INCLUDES` collapses to `personal` with
  **NO excludes**, so the whole graph becomes writable (own/shared/sets are
  subsumed). Capability, not authorization: every escalated write is
  `ask`-gated by an OpenCode permission (see below).

### Delivery namespaces (populated by roles)

The DELIVERY agents cannot write Logseq, so their trees are declared as named
bundles in `logseqNamespaceSets` and written by the knowledge roles:

| bundle | namespace | populated by |
| --- | --- | --- |
| `planOwn` | `ai-pln Planner_system` | analyst |
| `nixPlanOwn` | `ai-nxp NixPlanner_system` | nix-analyst |
| `builderOwn` | `ai-bld Builder_system` | reporter |
| `nixBuilderOwn` | `ai-nxb NixBuilder_system` | reporter |
| `buildPair` | `ai-s-bld shared-Builder_system` | (accessible, unused) |
| `planPair` | `ai-s-pln shared-Planner_system` | (accessible, unused) |

## Configuration

The module lives in
`modules/home/apps/ai-assistance/opencode/mcp.nix`. It exposes options under
`ds-omega.ai-assistance.opencode.mcp` (global values defined as `mkDefault` in
`logseq-profiles.nix`):

| Option | Meaning |
| --- | --- |
| `logseqSharedNamespaces` | Namespaces appended to every profile's write list (`ai Agents_system`). |
| `logseqNamespaceSets` | Named bundles (`attrsOf (listOf str)`) referenced by `writeSets` / `readSets`. |
| `logseqAgentProfiles` | Per-agent profiles derived into `logseq-<name>` servers (one per knowledge role). |
| `logseqSummarizerProfiles` | Derived narrow `summ-<parent>` profiles for the `<parent>-kbn` counterparts. |
| `logseqEscalatedProfiles` | Escalated write-everywhere profiles (one: `kbn-escalated`), kept out of `logseqAgentProfiles` so ordinary ACLs are unaffected. |
| `logseqSrc` | Nix-pinned mcp-logseq source (mounted + `uvx --from`; the image has no git). |

Each knowledge-role profile is:

```nix
<name> = {
  own = "…";                       # the role's own top-level namespace
  writeSets = [ "planOwn" ];       # bundles appended to LOGSEQ_WRITE_INCLUDES
  readSets = [ "discovery" ];      # bundles + the `personal` marker appended
                                   # to LOGSEQ_INCLUDE_NAMESPACES
  readAllAgentOwns = false;        # true = also read every OTHER profile's own
  readAllNamespaces = false;       # true (kbn only) = whole graph, no excludes
  writeAllNamespaces = false;      # true (kbn-escalated only) = whole-graph
                                   # write: WRITE collapses to `personal`
};
```

The derived per-server environment is:

```
LOGSEQ_WRITE_INCLUDES     = own, <logseqSharedNamespaces>, <sets(writeSets)>
                          [= just the `personal` marker when writeAllNamespaces]
LOGSEQ_INCLUDE_NAMESPACES = <sets(readSets)>
                           [+ every other profile's own when readAllAgentOwns]
                           [+ the `personal` marker when readAllNamespaces]
LOGSEQ_EXCLUDE_NAMESPACES = <derived, ONLY when readSets/writeSets carry the
                            `personal` marker, and NEVER for readAllNamespaces
                            or writeAllNamespaces>
                          = every OTHER profile's own + every set bundle the
                            profile does not reference
                            ("personal" = everything except these)
```

The reserved entry `personal` in `writeSets`/`readSets` means *everything not
excluded* (complement mode). It must always be paired with the derived excludes
— except for the whole-graph profiles (`readAllNamespaces` kbn and
`writeAllNamespaces` kbn-escalated), which deliberately have none. Never
enumerate personal namespaces in `logseqNamespaceSets`.

The values are the global namespace ACL, defined in
`modules/home/apps/ai-assistance/opencode/logseq-profiles.nix` (as `mkDefault`
values a host could override). Only the per-host glue (`logseqEnvironmentFile`,
`logseqHost`) stays in `homes/x86_64-linux/ds13@salt/apps/ecosystem/sops-opencode/default.nix`.

## Reference profile table (as configured for this user)

### Knowledge-role instances

| opencode agent | mode | server (port) | write includes | read extras |
| --- | --- | --- | --- | --- |
| orchestrator | primary | `logseq-orchestrator` (18113) | own, `ai Agents_system` | discovery, architecture, every other profile's own |
| strategist | primary | `logseq-strategist` (18108) | own, `ai Agents_system`, discovery | `personal`, architecture |
| tactician | subagent | `logseq-tactician` (18109) | own, `ai Agents_system` | discovery, architecture, every other profile's own |
| architect | subagent | `logseq-architect` (18110) | own, `ai Agents_system`, architecture | discovery, architecture |
| researcher | subagent | `logseq-researcher` (18111) | own, `ai Agents_system` | discovery, architecture |
| analyst | subagent | `logseq-analyst` (18112) | own, `ai Agents_system`, `ai-pln Planner_system`, `ai-s-pln shared-Planner_system` | discovery, architecture |
| nix-analyst | subagent | `logseq-nix-analyst` (18114) | own, `ai Agents_system`, `ai-nxp NixPlanner_system` | discovery, architecture |
| reporter | subagent | `logseq-reporter` (18115) | own, `ai Agents_system`, `ai-bld Builder_system`, `ai-nxb NixBuilder_system`, `ai-s-bld shared-Builder_system` | discovery, architecture |
| kbn | all | `logseq-kbn` (18103) | own, `ai Agents_system` | **whole graph** (`personal` marker, no excludes) |
| kbn (escalated) | all | `logseq-kbn-escalated` (18123) | **whole graph** (`personal` marker, no excludes; every write `ask`-gated) | — |

Own namespaces: orchestrator `ai-orc Orchestrator_system`, strategist
`ai-str Strategist_system`, tactician `ai-tcn Tactician_system`, architect
`ai-arc Architect_system`, researcher `ai-rsh Researcher_system`, analyst
`ai-anl Analyst_system`, nix-analyst `ai-nxl NixAnalyst_system`, reporter
`ai-rpt Reporter_system`, kbn `ai-kbn KnowledgeBaseNoter_system`.

`kbn-escalated` is **not** a tenth role: it is kbn's second gateway (same
agent, same own tree), defined in `logseqEscalatedProfiles` — deliberately
separate from `logseqAgentProfiles` so no other profile's derived
includes/excludes change. Its write list is the reserved `personal` complement
marker with NO excludes — the whole graph becomes writable (own/shared/sets
subsumed) — but capability is not authorization: every write through it is
`ask`-gated by an OpenCode permission (see
[OpenCode wiring](#opencode-wiring-in-mcpnix-settingsagent)).

### Summarizer instances (`<parent>-kbn` counterparts)

Each producing knowledge role (all except orchestrator and kbn) has a hidden
`<parent>-kbn` subagent on a dedicated narrow `logseq-summ-<parent>` instance:

| counterpart | server (port) | write includes | read |
| --- | --- | --- | --- |
| strategist-kbn | `logseq-summ-strategist` (18116) | `ai-str Strategist_system/_journals`, `ai Agents_system` | `ai-str Strategist_system` |
| tactician-kbn | `logseq-summ-tactician` (18117) | `ai-tcn Tactician_system/_journals`, `ai Agents_system` | `ai-tcn Tactician_system` |
| architect-kbn | `logseq-summ-architect` (18118) | `ai-arc Architect_system/_journals`, `ai Agents_system` | `ai-arc Architect_system` |
| researcher-kbn | `logseq-summ-researcher` (18119) | `ai-rsh Researcher_system/_journals`, `ai Agents_system` | `ai-rsh Researcher_system` |
| analyst-kbn | `logseq-summ-analyst` (18120) | `ai-anl Analyst_system/_journals`, `ai Agents_system` | `ai-anl Analyst_system` |
| nix-analyst-kbn | `logseq-summ-nix-analyst` (18121) | `ai-nxl NixAnalyst_system/_journals`, `ai Agents_system` | `ai-nxl NixAnalyst_system` |
| reporter-kbn | `logseq-summ-reporter` (18122) | `ai-rpt Reporter_system/_journals`, `ai Agents_system` | `ai-rpt Reporter_system` |

Their job is to journal a change the parent wrote: `Updated
[[<parent> page]]` + a simplified copy.

### Agents with no Logseq

| agent | class | reason |
| --- | --- | --- |
| plan, nix-plan, build, nix-build, verifier | DELIVERY | banks only; trees populated by analyst/nix-analyst/reporter |
| coding, prompt-designer | authoring | kept, no Logseq |

`ai-shared` is the global `ai Agents_system`; `discovery`/`architecture` are
the active shared trees (`ai-shared-Discovery_system` /
`ai-shared-Architecture_system`); `buildPair`/`planPair` are the retained-but-
unused pair trees (`ai-s-bld shared-Builder_system` / `ai-s-pln
shared-Planner_system`). `personal` is the derived complement (everything not
under an agent namespace) — never enumerated. The `-kbn` summarizer instances
are dedicated and narrow: they never reach the broad kbn instance
(`logseq-kbn_*`) or its escalated `kbn-escalated` sibling, so they can neither
read nor write personal namespaces.

## Container runtime: no git in the image

The workflow containers use `supercorp/supergateway:uvx`, which ships `uv` and
Python but **not** `git` — so a `uvx --from git+https://…@rev mcp-logseq` spec
fails at container start ("Git executable not found"). The Nix fix: instead of
a git URL, the mcp-logseq **source** is pinned as the flake input `mcp-logseq`
(`flake = false`, rev `aa5550e64d8486ee8329ee9320fc82452e4eb0c2` in
`flake.nix`), provided to the containers via `logseqSrc` (set by default in
`logseq-profiles.nix`). When `logseqSrc` is set, each logseq server:
- mounts the source read-only: `${logseqSrc}:/app/mcp-logseq:ro`, and
- runs `uvx --refresh --from /app/mcp-logseq mcp-logseq` (uv installs from a
  local directory — no git required).

To bump the installed revision, change the commit in the `mcp-logseq` flake
input URL (and the `aa5550e…` strings) and let the lockfile record the new
sha256 (`nix flake lock`, then `make switch`). If `logseqSrc` is `null` the
module falls back to the git-URL spec (backward compatible; the check keeps
asserting both paths).

## OpenCode wiring (in `mcp.nix`, `settings.agent`)

Top-level `settings.tools."logseq*" = false` disables logseq tools for
everyone. Each knowledge role then gets a per-agent grant of exactly its own
instance — `settings.agent.<name>.tools."logseq-<name>*" = true` — plus the
shared non-logseq `knowledge` bank (`time*`, `memory*`, `fetch*`,
`ddg-search*`). Special cases: `kbn` additionally gets the `filesystem*` bank
(the `/kbn` vault MCP) and is the only agent with two logseq globs —
`logseq-kbn_*` (deliberately narrowed from `logseq-kbn*`: the underscore keeps
the default grant from swallowing the escalated tool ids) plus
`logseq-kbn-escalated_*`; `nix-analyst` additionally gets `nixos*`. DELIVERY
agents carry the `delivery` / `deliveryNix` banks only (`deliveryNix` adds
`nixos*`) and **no `logseq-*` glob at all**. Each `<parent>-kbn` counterpart is
granted exactly `{logseq-summ-<parent>*}`.

The escalated `logseq-kbn-escalated_*` tools are gated per tool id by
`settings.agent.kbn.permission."logseq-kbn-escalated_*" = "ask"`: every write
they perform surfaces an approval prompt and executes only on explicit user
approval — deny/reject fails closed (nothing is written). The default
`logseq-kbn_*` tools stay ungated, so kbn's default write set (own + shared)
is unchanged, and the global `tools."logseq*" = false` remains the fallback.

Each agent is wired to **its own** instance only, never another agent's
(cross-instance grants would leak other profile trees). An agent without a
profile glob gets no logseq tools at all. There is deliberately **no generic
`logseq` container server** — logseq access exists only through explicit
profiles. The legacy `logseq-mcpo` gateway stays registered for NON-opencode
consumers of the shared MCP stack but is DISABLED in OpenCode only
(`settings.mcp."logseq-mcpo".enabled = false`); MCP tool ids are
`<mcp-client>_<tool>`, e.g. `logseq-reporter_<tool>`.

Agent relationships (tool banks, delegation, and the per-agent namespace
instances) are drawn in
[`docs/_diagrams/OpencodeAgents_diagram.puml`](../../docs/_diagrams/OpencodeAgents_diagram.puml).
The runtime/config boundary between the Unix_dotfiles MCP module and the
logseq-mcp fork (incl. the ACL contract and the operational gotchas) is drawn at
the repository root:
[`McpBoundaries_diagram.puml`](../../McpBoundaries_diagram.puml).

## Subagent delegation: `permission.task`, not `tools`

Since v1.2.5, OpenCode gates **subagent invocation** via `permission.task`
(glob/name → "allow"|"ask"|"deny") — the `task` tool filters which subagents a
caller may invoke, and a `deny`ed subagent is dropped from the Task tool
description. Evaluation semantics (from source): **the last matching rule
wins** (`findLast`); if NO rule matches the default action is `ask`; and the
`task` tool only hides subagents whose evaluation is `deny` (an `ask`e still
lists them). That is why delegation must block the OTHER counterparts
explicitly (`"*-kbn" = "deny"`); simply allowing one does not hide the rest.
`permission.task."<agent>-kbn" = "allow"` alone does NOT block other
subagents. The `tools` key is deprecated upstream but intentionally retained
in this repo for the MCP `logseq-*` glob grants (tool availability), which is a
different concern from delegation. So: **tool grants use `tools`; delegation
uses `permission.task`.**

### Counterparts (`<agent>-kbn`)

Each producing knowledge role (strategist, tactician, architect, researcher,
analyst, nix-analyst, reporter) delegates journaling of the changes it writes
to a hidden `<agent>-kbn` counterpart:

- Parent gets `permission.task = { "*-kbn" = "deny"; "<agent>-kbn" = "allow" }` —
  block the OTHER roles' counterparts, allow exactly its own (last-match-wins).
  We deliberately do NOT deny `*`: the parent must keep calling generic
  subagents (general/explore/etc.) for task decomposition.
- The counterpart is `mode: subagent`, `hidden: true` (invoked programmatically
  only), with its persona (`description`, `permission.bash = deny`) and its
  tool grants defined in `mcp.nix` `settings.agent`.
- Each counterpart uses a **dedicated, narrow instance** `logseq-summ-<parent>`
  (ports 18116–18122) whose ACL is: WRITE the parent's own
  `<parent-own>/_journals` tree (+ the global shared tree); READ the parent's
  own tree only (derived from the profile name). The counterpart's logseq glob
  set is exactly `{logseq-summ-<parent>*}` — it is **not** given the broad
  `logseq-kbn_*` instance (which may reach personal/shared) nor the parent's
  instance, so it can never read or write personal namespaces.

`kbn` (the noter, whole-graph) and `orchestrator` (the coordinator/status
writer) have no counterparts; DELIVERY agents have no Logseq so they have none
either.

## Debugging actual permissions (no e2e needed)

The committed source defines the effective permissions; verify them statically:

```sh
opencode debug config            # fully resolved config, incl. per-agent `permission` (task rules, tools→permission)
opencode debug agent <name>      # per TOOL availability map ({<tool-id>: true|false}) for an agent,
                                 # e.g. `opencode debug agent reporter` shows logseq-reporter_* on/off
opencode agent list              # list agents (their mode/description)
```

Source semantics to reason about the output (v1.2.5 clone): legacy `tools`
entries become permissions (`true`→`allow`, `false`→`deny`, mapping write/edit/
patch/multiedit→`edit`), merged per agent AFTER the global rules (so an
agent-level `logseq-reporter* = allow` overrides the top-level `logseq* = deny`);
`permission` is evaluated with **last-match-wins** and **default `ask`**;
`task` only removes `deny`ed subagents. MCP tool ids are `<client>_<tool>`, so
glob `logseq-<name>*` matches them. `tools` and `permission` stack:
`tools."logseq-kbn-escalated_*" = true` makes kbn's escalated tools available
while `permission."logseq-kbn-escalated_*" = "ask"` demands per-write user
approval (the default `logseq-kbn_*` tools are ungated). A static Nix audit of
the derived grants/task rules is in `checks/mcp-logseq/default.nix` (the
`permission.task` `*-kbn` blocking, per-agent glob isolation, and the
`logseq-kbn-escalated_*` ask gate are asserted there).

## Adding a new agent

1. **Classify the agent.** If it executes work without reasoning over the
   graph it is a DELIVERY agent: give it a tool bank in `mcp.nix`
   (`delivery` / `deliveryNix`) and STOP — no profile, no port, no `logseq-*`
   glob, no credentials. If it is a knowledge role, continue.
2. Give the knowledge role a dedicated top-level namespace (convention
   `<x>_system`).
3. Add a `logseqAgentProfiles.<name>` entry with `own` (and `writeSets` /
   `readSets` / `readAllAgentOwns` / `readAllNamespaces` as needed) in
   `logseq-profiles.nix`; allocate a host port in `logseqPorts` in `mcp.nix`.
4. Define (or point to) the agent in `programs.opencode.settings.agents` /
   `settings.agent`, grant the shared `knowledge` bank plus
   `"logseq-<name>*" = true` in `settings.agent.<name>.tools` (module's agent
   block).
5. If the role journals changes it writes into its own tree, add it to
   `producingParents` in `logseq-profiles.nix` (derives its `summ-<parent>`
   profile), create its `<parent>-kbn` counterpart via `mkKbnCounterpart` and
   its `delegateTo` rule in `mcp.nix`. Orchestrator-like coordinators and kbn
   get neither.
6. Extend `checks/mcp-logseq/default.nix` if new servers/agents are introduced
   (expected server list, delegation, personas).
7. Apply and restart — REQUIRED before the next OpenCode session:

   ```sh
   make switch       # apply home-manager (writes the Compose + OpenCode config)
   make mcp-restart  # recreate containers so OpenCode registers the new tools
   ```

   Optionally verify the stack with `make mcp-bootstrap && make mcp-start &&
   make mcp-status`.

## Debugging

The canonical check lives at `checks/mcp-logseq/default.nix` and the debug dump
at `checks/mcp-logseq/debug.nix`. Both evaluate the real `mcp.nix` module
(the check and the debug dump source the global namespace values from
`logseq-profiles.nix`; only the host glue `logseqEnvironmentFile`/`logseqHost`
is that host's per-host data) and require no switch.

`make mcp-logseq-check` builds the Snowfall `checks.<system>.mcp-logseq`
derivation, asserting every invariant and the full oracle env (the **17-server
env**: 9 knowledge-role + the `kbn-escalated` write-everywhere instance +
7 `logseq-summ-<parent>` instances); it aborts loudly (build fails) on any
mismatch:

```sh
make mcp-logseq-check
# equivalent: nix build .#checks.x86_64-linux.mcp-logseq
```

`make mcp-logseq-debug` prints, per agent, the actual derived ACL contract
sent to each mcp-logseq server:

```sh
make mcp-logseq-debug
```

Example output (abridged):

```json
{
  "logseq-reporter": {
    "server": "logseq-reporter",
    "agent": "reporter",
    "hostPort": 18115,
    "LOGSEQ_WRITE_INCLUDES": "ai-rpt Reporter_system,ai Agents_system,ai-bld Builder_system,ai-nxb NixBuilder_system,ai-s-bld shared-Builder_system",
    "LOGSEQ_INCLUDE_NAMESPACES": "ai-shared-Discovery_system,ai-shared-Architecture_system",
    "LOGSEQ_EXCLUDE_NAMESPACES": null,
    "stdioPin": "aa5550e64d8486ee8329ee9320fc82452e4eb0c2",
    "logseqToolGrant": ["logseq-reporter*"]
  },
  "logseq-kbn": {
    "server": "logseq-kbn",
    "agent": "kbn",
    "hostPort": 18103,
    "LOGSEQ_WRITE_INCLUDES": "ai-kbn KnowledgeBaseNoter_system,ai Agents_system",
    "LOGSEQ_INCLUDE_NAMESPACES": "personal",
    "LOGSEQ_EXCLUDE_NAMESPACES": null,
    "stdioPin": "aa5550e64d8486ee8329ee9320fc82452e4eb0c2",
    "logseqToolGrant": ["logseq-kbn-escalated_*", "logseq-kbn_*"]
  },
  "logseq-summ-reporter": {
    "server": "logseq-summ-reporter",
    "agent": "reporter-kbn",
    "hostPort": 18122,
    "LOGSEQ_WRITE_INCLUDES": "ai-rpt Reporter_system/_journals,ai Agents_system",
    "LOGSEQ_INCLUDE_NAMESPACES": "ai-rpt Reporter_system",
    "LOGSEQ_EXCLUDE_NAMESPACES": null,
    "stdioPin": "aa5550e64d8486ee8329ee9320fc82452e4eb0c2",
    "logseqToolGrant": ["logseq-summ-reporter*"]
  }
}
```
