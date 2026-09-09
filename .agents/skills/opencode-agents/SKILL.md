---
name: opencode-agents
description: This skill should be used when adding, renaming, or wiring an OpenCode agent in this Unix_dotfiles repository — classifying it as a knowledge role (own per-agent Logseq tree / "own kbn") or a DELIVERY agent (no Logseq at all), its OpenCode persona and tool bank, optional delegation to a hidden <parent>-kbn summarizer counter-part that journals its changes, and the restart requirement. Read the accepted ADR docs/adr/0005-agent-roles-and-logseq-access.md and the guide docs/guides/logseq-agent-namespaces.md before editing.
---

# Add / wire an OpenCode agent

Use this skill for a new OpenCode agent in the per-agent Logseq namespace ACL
system. Read [ADR 0005](../../docs/adr/0005-agent-roles-and-logseq-access.md)
(the operative decision record; [ADR 0004](../../docs/adr/0004-logseq-agent-namespaces.md)
is superseded history) and the
[namespace guide](../../docs/guides/logseq-agent-namespaces.md) first — they are
the authoritative decisions; this skill is the how-to.

## First: classify the agent

- **Knowledge role** — reasons over the Logseq graph; gets exactly one own
  `logseq-<role>` instance. The role set: orchestrator (primary, coordinator),
  strategist (primary), tactician, architect, researcher, analyst, nix-analyst,
  reporter (subagents), and kbn (mode `all`, whole-graph noter).
- **DELIVERY agent** — `plan`, `nix-plan`, `build`, `nix-build`, `verifier`:
  executes work with **NO Logseq at all** (no server, no `logseq-*` tools glob,
  no credentials). Its result tree exists as a namespace bundle
  (`planOwn` / `nixPlanOwn` / `builderOwn` / `nixBuilderOwn`) that the knowledge
  roles populate for it.
- `coding` / `prompt-designer` are authoring personas: kept, no Logseq.

## The three Logseq surfaces an agent can talk to

An agent NEVER talks to a generic `logseq` server. There are only three kinds of
instances it may be granted:

1. **Its own tree (`logseq-<name>`)** — "its own kbn": the dedicated
   `logseq-<role>` gateway whose ACL is `own ++ ai Agents_system ++
   sets(writeSets)` (+ read extras via `readSets`, `readAllAgentOwns`, or —
   kbn only — `readAllNamespaces`). Grant glob `logseq-<name>*`. Every
   knowledge role gets exactly its own instance.
2. **The broad knowledge-noter (`logseq-kbn`)** — the whole-graph instance:
   `readAllNamespaces` (the `personal` marker with NO excludes). ONLY grant
   `logseq-kbn_*` (note the underscore — narrowed so it cannot swallow the
   escalated tools) to kbn itself, and only kbn gets the `filesystem*` `/kbn`
   vault bank alongside it. Do not grant it to any other role — that leaks
   personal and every other tree. kbn additionally carries the escalated
   write-everywhere instance `logseq-kbn-escalated` (port 18123,
   `writeAllNamespaces`): whole-graph WRITE, with every escalated tool gated
   by `permission."logseq-kbn-escalated_*" = "ask"` (deny/reject fails
   closed).
3. **A dedicated journaling instance (`logseq-summ-<parent>`)** — a NARROW
   instance used by the hidden `<parent>-kbn` summarizer counterpart: WRITEs
   the parent's own `<parent-own>/_journals` tree (+ `ai Agents_system`) and
   READs only the parent's own tree. Grant glob `logseq-summ-<parent>*`. This
   is how a producing role's changes are journaled (`Updated [[<parent> page]]`
   + a simplified copy) WITHOUT exposing the broad kbn instance or personal.

Which roles get which surface:

| surface | granted to |
| --- | --- |
| own `logseq-<name>*` | every knowledge role: orchestrator, strategist, tactician, architect, researcher, analyst, nix-analyst, reporter, kbn |
| broad `logseq-kbn_*` + ask-gated `logseq-kbn-escalated_*` (+ `filesystem*`) | kbn only |
| narrow `logseq-summ-<parent>*` | the hidden `<parent>-kbn` counterpart of every producing role EXCEPT orchestrator and kbn: strategist-kbn, tactician-kbn, architect-kbn, researcher-kbn, analyst-kbn, nix-analyst-kbn, reporter-kbn |
| none | DELIVERY agents (plan, nix-plan, build, nix-build, verifier), coding, prompt-designer |

## Principles that must hold

- **Flat banks, leaf grants:** non-logseq tool grants come from the flat
  `baseTools`-derived banks in `mcp.nix` — `knowledge`
  (time/memory/fetch/ddg-search) for knowledge roles (kbn also `filesystem`,
  nix-analyst also `nixos`), `delivery` / `deliveryNix` for DELIVERY agents.
  There is no cross-agent inheritance chain anymore.
- **Isolation invariant:** each `logseqGrant` (`logseq-<own>*`, or
  `logseq-summ-<parent>*` for counterparts) is applied at the LEAF only, never
  inherited. No agent may carry another agent's `logseq-*` glob, and a DELIVERY
  agent carries none at all.
- **DELIVERY agents get no Logseq:** do not add a profile, a port, a
  `logseq-*` grant, or credentials to plan/nix-plan/build/nix-build/verifier.
  Their trees are populated by analyst / nix-analyst / reporter.
- **Block-other-counterparts delegation:** a producing role that journals via a
  `<parent>-kbn` summarizer must have
  `permission.task = { "*-kbn" = "deny"; "<parent>-kbn" = "allow" }` — do NOT use
  `"*" = "deny"` (that would break the agent's normal task decomposition via
  general/explore/etc.) and do NOT rely on a bare allow (unlisted subagents are
  `ask`ed, and the task tool only hides `deny`). orchestrator and kbn carry no
  delegation (they have no counterpart).
- **Personal is derived, not enumerated:** to make an agent read/write
  "personal", put the literal marker `personal` in `writeSets`/`readSets` (the
  module derives `exclude_namespaces` = other profiles' own + unreferenced
  bundles). Never list personal namespaces. The exceptions are kbn's
  `readAllNamespaces` and the escalated `kbn-escalated`'s `writeAllNamespaces`
  (whole graph, no excludes).
- **No generic server / no mcpo in opencode:** never add a bare `logseq`
  server and never enable `logseq-mcpo` in OpenCode (it stays registered but
  disabled for non-opencode consumers).

## How to add a new agent

1. **Classify.** DELIVERY agent → add it to `mcp.nix` `settings.agent` with
   `tools = delivery` (or `deliveryNix` for the Nix pair), plus the persona
   (`mode: subagent`, description) — and STOP. No profile, no port, no logseq
   grant. Knowledge role → continue.
2. **Namespace profile** — add `logseqAgentProfiles.<name>` (or a set bundle in
   `logseqNamespaceSets` for trees a role must reach but does not own, e.g. the
   planner/builder trees) in
   `modules/home/apps/ai-assistance/opencode/logseq-profiles.nix`; allocate a
   non-conflicting host port in `logseqPorts` in `mcp.nix` (kbn is 18103; the
   other role instances use 18108–18115; the escalated write-everywhere
   `kbn-escalated` instance uses 18123; summarizers use 18116–18122).
3. **Persona** — add the agent in `mcp.nix` `settings.agent` (pure-JSON
   subagents, `mode`, `description`, `hidden` as needed; primary personas may
   alternatively live as markdown in `default.nix` `settings.agents`).
4. **Tools** — `tools = knowledge // (logseqGrant "<name>").tools` (add
   `baseTools.filesystem` for a noter, `baseTools.nixos` for a nix role).
5. **kbn wiring — three cases:**
   - The role journals changes it writes into its own tree (every producing
     knowledge role EXCEPT orchestrator and kbn): add it to `producingParents`
     in `logseq-profiles.nix` (derives its `summ-<parent>` profile and instance
     port), then in `mcp.nix` add the `<parent>-kbn` agent via
     `mkKbnCounterpart "<parent>"` and give the parent `delegateTo "<parent>"`
     (`permission.task."*-kbn" = deny` + `"<parent>-kbn" = allow`).
   - The role IS the noter (kbn): grant `logseq-kbn_*` + the escalated
     `logseq-kbn-escalated_*` (with `permission."logseq-kbn-escalated_*" =
     "ask"`) + `filesystem*` instead — kbn is the only whole-graph agent, with
     no counterpart.
   - The role is a coordinator (orchestrator): own instance only, no
     counterpart, no `delegateTo`.
6. If a NEW subagent/counterpart/server is introduced, extend
   `checks/mcp-logseq/default.nix` (expected 17 servers, delegations, personas,
   glob isolation) so the change is asserted statically.

## After changing agent wiring

```sh
make switch            # apply home-manager
make mcp-restart       # recreate containers so OpenCode registers the tools
```

`make mcp-restart` is REQUIRED after any change to agent wiring (servers,
grant globs, ports) and MUST run BEFORE starting an OpenCode session:
OpenCode registers MCP tools at session start from the running containers, so
without the restart it will not see the new tools (and may cache stale tool
lists).

Optionally audit without e2e:

```sh
opencode debug config          # merged config incl. per-agent permission/task
opencode debug agent <name>    # per-tool availability map for an agent
make mcp-logseq-check          # static derivation oracle (aborts on mismatch)
make mcp-logseq-debug          # per-agent ACL contract as JSON
```

## Completion checklist

- [ ] Read ADR 0005 (and ADR 0004 for superseded history) and the namespace
      guide.
- [ ] Agent classified: knowledge role (own `logseq-<role>` instance) vs
      DELIVERY (no Logseq — banks only, no profile/port/glob).
- [ ] Profile (`own`/sets) added in `logseq-profiles.nix`; port allocated
      (role 18108–18115, escalated `kbn-escalated` 18123, summarizer
      18116–18122).
- [ ] Persona + tools added in `settings.agent` with the flat
      `knowledge`/`delivery` banks and the logseq grant isolated at the leaf.
- [ ] DELIVERY agents carry zero `logseq-*` globs.
- [ ] Only kbn carries the kbn globs (`logseq-kbn_*` + ask-gated
      `logseq-kbn-escalated_*`, + `filesystem*`); no other role reaches the
      broad whole-graph instances.
- [ ] Journaling goes through a narrow `logseq-summ-<parent>` instance on a
      hidden `<parent>-kbn` counterpart (orchestrator and kbn: none).
- [ ] Delegation uses `permission.task` `*-kbn` deny + own `<parent>-kbn`
      allow (never a tools glob, never a blanket `"*" = "deny"`).
- [ ] `make mcp-logseq-check` passes (check extended if new servers/agents).
- [ ] `make switch` then `make mcp-restart` BEFORE the next OpenCode session.
