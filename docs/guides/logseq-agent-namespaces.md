# Logseq agent-namespace profiles (per-agent MCP instances)

This guide defines how the Logseq review-report system's per-agent restriction
is configured. It explains the setting, how OpenCode is wired to it, and why
the namespace ACL lives in a per-agent process rather than in OpenCode's own
permissions model.

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
  wins). Required whenever the reserved `personal` marker is used (below).

All gateway containers point at the same Logseq API with the same token. The
host ports (`18103` for `logseq-kbn`, `18108`..`18113` for the others) are
gateway ports, **not Logseq instances** — Logseq remains exactly one app.

## Why the ACL lives in the process env, not in OpenCode

OpenCode's permissions/tools model is **tool-name-pattern based**. It can
enable/disable whole tools per agent (e.g. `"logseq-build*"`), but it cannot
express *"this agent may only write namespace `bil Builder_system`"* — that is
a constraint on tool **arguments** (the page title), which OpenCode does not
inspect. So the hard namespace ACL is enforced by the per-agent mcp-logseq
process, and OpenCode's per-agent `tools` globs are only the **wiring** that
exposes each instance to its owner.

## Namespace model

- **own** — the agent's dedicated top-level namespace (e.g. `ai-bld
  Builder_system` for `build`, `ai-pln Planner_system` for `plan`,
  `ai-nxb NixBuilder_system` for `nix-build`). Everything under it is the
  agent's own notes.
- **shared** — namespaces every (configured) agent may read AND write.
  `logseqSharedNamespaces` is appended to every profile's write list
  (currently `ai Agents_system`). Additional pair/topic shared trees go in
  `logseqNamespaceSets` and are referenced per profile by `writeSets`.
- **personal** — DERIVED, not enumerated: every namespace that is *not* under
  an agent-defined namespace (agent `own` trees and their set bundles). A
  profile opts in with the reserved marker `personal` in its `writeSets`
  and/or `readSets`; the module derives `exclude_namespaces` = all other
  agents' own trees + set bundles the profile does not reference, so the
  profile sees "everything except the other agents' worlds". E.g. with
  build's own = `ai-bld Builder_system`, `[[ai-bld Builder_system]]` and
  `[[ai-bld Builder_system/AiAssistance]]` are build's own notes, while
  `[[AiAssistance]]`, `[[rut Rutube_system/AiAssistance]]` are personal.
- **approval flow is COPY-based**: an approver profile (orchestrator) can read
  an agent tree and write a shared tree, but `rename_page` write-checks BOTH
  names — so it cannot move a page *out* of an agent tree. Approved content is
  copied under a shared tree; the owning agent cleans up its own inbox.

## Configuration

The module lives in
`modules/home/apps/ai-assistance/opencode/mcp.nix`. It exposes three options
under `ds-omega.ai-assistance.opencode.mcp`:

| Option | Meaning |
| --- | --- |
| `logseqSharedNamespaces` | Namespaces appended to every profile's write list. |
| `logseqNamespaceSets` | Named bundles (`attrsOf (listOf str)`) referenced by `writeSets` / `readSets`. |
| `logseqAgentProfiles` | Per-agent profiles derived into `logseq-<name>` servers. |

Each profile is:

```nix
<name> = {
  own = "…";                       # the agent's own top-level namespace
  writeSets = [ "buildPair" ];     # bundles appended to LOGSEQ_WRITE_INCLUDES
  readSets = [ "personal" ];       # bundles + the `personal` marker appended
                                   # to LOGSEQ_INCLUDE_NAMESPACES
  readAllAgentOwns = false;        # true = also read every OTHER profile's own
};
```

The derived per-server environment is:

```
LOGSEQ_WRITE_INCLUDES     = own, <logseqSharedNamespaces>, <sets(writeSets)>
LOGSEQ_INCLUDE_NAMESPACES = <sets(readSets)> [+ every other profile's own]
LOGSEQ_EXCLUDE_NAMESPACES = <derived, ONLY when readSets/writeSets carry
                            the `personal` marker> = every OTHER profile's
                            own + every set bundle the profile does not
                            reference ("personal" = everything except these)
```

The reserved entry `personal` in `writeSets`/`readSets` means *everything not
excluded* (complement mode). It must always be paired with the derived
excludes — never enumerate personal namespaces in `logseqNamespaceSets`.

The values are the global namespace ACL, defined in
`modules/home/apps/ai-assistance/opencode/logseq-profiles.nix` (as `mkDefault`
values a host could override). Only the per-host glue (`logseqEnvironmentFile`,
`logseqHost`) stays in `homes/x86_64-linux/ds13@salt/apps/ecosystem/sops-opencode/default.nix`.

OpenCode wiring (in `mcp.nix`, `settings.agent`): the module adds the tool
glob `"logseq-<name>*" = true` to each agent whose profile exists — each agent
is wired to **its own** instance only, never another agent's (cross-instance
grants would leak other profile trees). Top-level `"logseq*" = false`
disables everything for everyone else, so an agent without a profile glob gets
no logseq tools at all. There is deliberately **no generic `logseq` server** —
logseq access exists only through explicit profiles.

## Subagent delegation: `permission.task`, not `tools`

Since v1.2.5, OpenCode gates **subagent invocation** via `permission.task`
(glob/name → "allow"|"ask"|"deny") — the `task` tool filters which subagents a
caller may invoke, and a `deny`ed subagent is dropped from the Task tool
description. Users can still `@`-mention any subagent directly. The `tools`
key is deprecated upstream but intentionally retained in this repo for the MCP
`logseq-*` glob grants (tool availability), which is a different concern from
delegation. So: **tool grants use `tools`; delegation uses `permission.task`.**

### Counterparts (`<agent>-kbn`)

Each producing agent (build, plan, nix-build, nix-plan, docs-writer) delegates
result-summarization to a hidden `<agent>-kbn` counterpart:

- Parent gets `permission.task."<agent>-kbn" = "allow"` — exactly its own
  counterpart, nothing broader.
- The counterpart is `mode: subagent`, `hidden: true` (invoked programmatically
  only), with its persona (`description`, `permission.bash = deny`) and its
  tool grants defined in `mcp.nix` `settings.agent`.
- A counterpart's logseq glob set is exactly `{logseq-kbn*, logseq-<parent>*}`:
  `logseq-kbn*` is its only write surface (the knowledge-noter instance);
  `logseq-<parent>*` lets it read the parent's results to summarize them. It
  gets **no other** agent's logseq grant.

kbn (the noter) and orchestrator (the reviewer) have no counterparts.

## Adding a new agent profile

1. Give the agent a dedicated top-level namespace (convention `<x>_system`).
2. Add a `logseqAgentProfiles.<name>` entry with `own` (and `writeSets` /
   `readSets` as needed) in `logseq-profiles.nix`; allocate a host port in
   `logseqPorts` in `mcp.nix`.
3. Define (or point to) the agent in `programs.opencode.settings.agents` and
   grant `"logseq-<name>*" = true` in `settings.agent.<name>.tools` (addible in
   the module's agent block).
4. Switch, then reconcile the MCP stack:

   ```sh
   make mcp-bootstrap && make mcp-start && make mcp-status
   ```

5. Verify an MCP handshake against the new loopback port and `opencode mcp list`.

## Reference profile table (as configured for this user)

| opencode agent | server | write includes | read extras |
| --- | --- | --- | --- |
| kbn | `logseq-kbn` (18103) | own, ai-shared, plan-shared, `personal` | — |
| build | `logseq-build` (18108) | own, ai-shared, build-shared | — |
| plan | `logseq-plan` (18109) | own, ai-shared, plan-shared | `personal` |
| docs-writer | `logseq-docs-writer` (18110) | own, ai-shared | — |
| nix-build | `logseq-nix-build` (18111) | own, ai-shared, build-shared | — |
| nix-plan | `logseq-nix-plan` (18112) | own, ai-shared, plan-shared | `personal` |
| orchestrator | `logseq-orchestrator` (18113) | own, ai-shared | every other profile's own |

`ai-shared` is the global `ai Agents_system`; `build-shared`/`plan-shared` are
the `buildPair`/`planPair` bundles. `personal` is the derived complement
(everything not under an agent namespace) — never enumerated.

**Current namespace values** (from `logseq-profiles.nix`, `ds13@salt` host): kbn
`ai-kbn KnowledgeBaseNoter_system`, build `ai-bld Builder_system`, plan
`ai-pln Planner_system`, docs-writer `ai-dwt DocsWriter_system`, nix-build
`ai-nxb NixBuilder_system`, nix-plan `ai-nxp NixPlanner_system`, orchestrator
`ai-orc Orchestrator_system`, shared `ai Agents_system`,
buildPair `ai-s-bld shared-Builder_system`, planPair `ai-s-pln
shared-Planner_system`.

## Debugging

The canonical check lives at `checks/mcp-logseq/default.nix` and the debug dump
at `checks/mcp-logseq/debug.nix`. Both evaluate the real `mcp.nix` module
(the check and the debug dump source the global namespace values from
`logseq-profiles.nix`; only the host glue `logseqEnvironmentFile`/`logseqHost`
is that host's per-host data) and require no switch.

`make mcp-logseq-check` builds the Snowfall `checks.<system>.mcp-logseq`
derivation, asserting every invariant and the full oracle env; it aborts
loudly (build fails) on any mismatch:

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
  "logseq-build": {
    "server": "logseq-build",
    "agent": "build",
    "hostPort": 18108,
    "LOGSEQ_WRITE_INCLUDES": "ai-bld Builder_system,ai Agents_system,ai-s-bld shared-Builder_system",
    "LOGSEQ_INCLUDE_NAMESPACES": null,
    "LOGSEQ_EXCLUDE_NAMESPACES": null,
    "stdioPin": "aa5550e64d8486ee8329ee9320fc82452e4eb0c2",
    "logseqToolGrant": ["logseq-build*"]
  },
  "logseq-kbn": {
    "server": "logseq-kbn",
    "agent": "kbn",
    "hostPort": 18103,
    "LOGSEQ_WRITE_INCLUDES": "ai-kbn KnowledgeBaseNoter_system,ai Agents_system,ai-s-pln shared-Planner_system,personal",
    "LOGSEQ_INCLUDE_NAMESPACES": null,
    "LOGSEQ_EXCLUDE_NAMESPACES": "ai-bld Builder_system,ai-dwt DocsWriter_system,ai-nxb NixBuilder_system,ai-nxp NixPlanner_system,ai-orc Orchestrator_system,ai-pln Planner_system,ai-s-bld shared-Builder_system",
    "stdioPin": "aa5550e64d8486ee8329ee9320fc82452e4eb0c2",
    "logseqToolGrant": ["logseq-kbn*"]
  }
}
```