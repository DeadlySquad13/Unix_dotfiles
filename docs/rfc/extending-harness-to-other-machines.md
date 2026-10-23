# RFC — Extending the harness mechanism to other machines

- **Status:** Proposed
- **Date:** 2026-10-18
- **Related:** [ADR 0007](../adr/0007-agent-harness-iteration-and-merge-gates.md)
  (merge gates), [ADR 0006](../adr/0006-agent-child-flake-and-repo-policy.md)
  (child-flake policy), [ADR 0003](../adr/0003-inner-system-inner-home.md)
  (inner system/inner home), [ADR 0005](../adr/0005-agent-roles-and-logseq-access.md)
  (agent roles / Logseq access),
  [RFC: agent-child-flake-inheritance](agent-child-flake-inheritance.md),
  [Guide: agent-harness iteration](../guides/agent-harness-iteration.md).

## Context

The harness mechanism (child checkout + bounded inner merge + host gates +
separate promotion, plus the `harness` invoke collection) is currently wired for
one machine, `darkGreen-tangerineDream-green`. This RFC says how to give another
machine the same capability, using a worked example: adding a **`green-cubanelle`**
host.

The mechanism is **namespace-generated**, so most of the work is declaring the
new machine and allocating the per-namespace names/ports; almost nothing in the
mechanism itself is hand-maintained.

## The two axes

Every machine is named `<spiceNamespace>-<systemBaseName>`:

- **`spiceNamespace`** — the *capability* group. It classifies a machine as
  "sandbox with strong in-sandbox capabilities" (NixOS + agent harness), as
  opposed to a plain container. It is carried by
  `lib.ds-omega.common.spiceNamespace` and drives: the `/usr/local/<spice>-/…`
  mount namespace, the `sops-opencode` paths, the runtime-home-bridge
  `namespaceRoot`, and the generated `<spice>-inner-conv-plat-prov` agent name.
- **`systemBaseName`** — the *machine* variant within the namespace
  (`lib.ds-omega.common.systemBaseName`). It selects the container user, the
  host data directories (`/zsalt/var-<user>@<system>/…`), the image, and the
  child branch/paths.

For `green-cubanelle`: `spiceNamespace = "green"`, `systemBaseName = "cubanelle"`,
so `SYSTEM_NAME = green-cubanelle`, the mount prefix is `/usr/local/green-/…`,
the child is `ai-/green-/cubanelle`, and the provisioner is
`green-inner-conv-plat-prov`.

> **Capability note.** ADR 0005/0007 key the inner-writer capability on the
> namespace. If `green` is meant to be a *darkGreen-class* sandbox (its agents
> may edit and merge its `_inner`), it needs the full wiring below. A plain
> container needs none of it — it gets no inner-writer agent. Decide this first;
> it is the only real branch in the checklist.

## 1. Parent repo (`Unix_dotfiles`) — what to add

Snowfall discovers these by path; there is **no central registry** to edit for
the flake to see a new system/home. Add:

| Path | Purpose | Must set |
| --- | --- | --- |
| `systems/x86_64-linux/<spice>-<base>_inner/` | the sandbox inner system | `lib.<ns>.common = { spiceNamespace; systemBaseName; }`; container user; `boot.isContainer`; module enables |
| `homes/x86_64-linux/<user>@<spice>-<base>_inner/` | the sandbox inner home | `home.username`/`homeDirectory`; `lib.<ns>.paths` + `mkResolutions`; the bridge **catalog** name; module enables |
| `systems/x86_64-docker/<spice>-<base>/` | the outer/image system | imports `apps/ecosystem/sops-opencode` and `services/runtime-home-bridge`; the same `common`; `system.activationScripts.fixDockerMountPermissions` for the `<spice>-` namespace dirs |
| `homes/x86_64-linux/<user>@<spice>-<base>/` | the outer home | mirrors the existing outer home (module enables, opencode on) |

Mirror an existing machine (the green pair) module-for-module; the only
machine-specific values are the `common` pair, the usernames, and the catalog
name.

## 2. Parent repo — what to touch (shared modules)

These are shared and therefore **host-edited** (promotion), not inner-edited:

| Module | Change |
| --- | --- |
| `modules/home/apps/ai-assistance/opencode/logseq-profiles.nix` | The `<spice>-inner-conv-plat-prov` profile is **derived** from `common.spiceNamespace`, so a new namespace that is darkGreen-class yields `<spice>-inner-conv-plat-prov` automatically. Confirm the new machine's provisioner is intended and, if it produces Logseq, that it lands in `producingParents`. |
| `modules/home/apps/ai-assistance/opencode/default.nix` | The provisioner persona is registered as `programs.opencode.agents."${innerProvisionerAgent}" = ./agents/<persona>.md`. Today the persona file is the green one; **generalize** it (one shared persona, or a per-namespace file) so the new agent name resolves to a real persona. |
| `modules/home/apps/ai-assistance/opencode/mcp.nix` | Allocate a **new Logseq port pair**: `<spice>-inner-conv-plat-prov` + `summ-<spice>-inner-conv-plat-prov` (the registry currently ends at the green pair). Also add the provisioner to per-agent `tools` grants / `permission.task` if it should be callable. |
| `checks/mcp-logseq/default.nix` | The oracle currently asserts the **green** names/ports/count. Extend it for the new namespace's provisioner + summarizer (names, ports, isolation, delegation) — or, preferably, make the oracle per-namespace so counts are not globally hardcoded. |
| `lib/runtime-home-bridge/default.nix` | The `convPlatProv` variant and the per-machine **catalog** live here; add the `<spice>-<base>` catalog entry the inner home references. |
| `packages/` | Only if the machine needs tooling packaged by Nix and shared. |
| `.gitignore` / `docs/` | Already generic (`ai-/` is ignored; ADR 0007 documents the mechanism). No change unless a per-namespace doc is wanted. |

`flake.nix` needs **no change**: Snowfall auto-discovers systems/homes. Touch
`deploy.nodes` only if the machine is deployed over SSH by `deploy-rs`.

## 3. MCP touch points (summary)

Adding a namespace that is darkGreen-class touches MCP wiring in exactly these
places:

1. **Per-agent Logseq instances** (`mcp.nix`): one new instance
   `logseq-<spice>-inner-conv-plat-prov` + one `logseq-summ-…`, each with a
   **new host port**; the profile body comes from `logseq-profiles.nix`.
2. **Server registry** (`mcp.nix` `mcpContainers.servers`) and
   `settings.mcp.servers`: only if the new machine needs a *different MCP set*
   (otherwise it reuses the same registry).
3. **Static oracle** (`checks/mcp-logseq`): new expected names/ports and, if the
   count is asserted globally, an updated count.
4. **Host glue** (the machine's `apps/ecosystem/sops-opencode` module):
   `logseqEnvironmentFile` + `logseqHost` (the SOPS-rendered Logseq token env
   file and the LAN hostname the containers resolve).
5. **MCP container service**: the generated compose / `opencode-mcp.service`
   is per-host; the machine's activation/enable flags control it.

## 4. Deployment repo (`@tangerineDream`)

| Artifact | Purpose |
| --- | --- |
| `docker-compose.<spice>-<base>.yml` | binds: `UNIX_DOTFILES_AI` (child, rw), `UNIX_DOTFILES_PARENT` (parent, **ro**), `SHARED_SCRIPTS_AI`, the SOPS age key, the runtime-home-bridge share dir |
| `.env.<spice>-<base>` + `.example` | `SPICE_NAMESPACE`, `SYSTEM_BASE_NAME`, `CONTAINER_USERNAME`, `BOOKMARKS`, `UNIX_DOTFILES_AI=${BOOKMARKS}/shared-configs/Unix_dotfiles/ai-/${SPICE_NAMESPACE}-/${SYSTEM_BASE_NAME}`, `UNIX_DOTFILES_PARENT`, `Z_NAMESPACE=/z${SYSTEM_BASE_NAME}`, `OPENCODE_*`, `SOPS_AGE_KEYS`, `IMAGE_*`, `RUNTIME_HOME_BRIDGE_CONFIG` |
| `configs/runtime-home-bridge/<spice>-<base>.json` | the bridge variant the container emits |
| `Makefile` / `Makefile.switch-nixos` | the `switch-<system>-system` and `connect-nixos-inner*` targets are parameterized by `SYSTEM_NAME`; usually no code change, just the new env file |
| `AGENTS.md` | the in-container tooling guidance; generalize it from green-specific to `<system>`-generic |

## 5. Host bootstrap + verify

```sh
# 1. Land the new files (the flake only sees git-tracked files).
git add systems/x86_64-linux/<spice>-<base>_inner homes/x86_64-linux/<user>@<spice>-<base>_inner \
        systems/x86_64-docker/<spice>-<base> homes/x86_64-linux/<user>@<spice>-<base>

# 2. Sanity-check the mechanism's view of the new machine.
invoke --search-root=./tasks harness.selfcheck --spice <spice> --agent <base>

# 3. Create the child checkout.
invoke --search-root=./tasks harness.bootstrap --spice <spice> --agent <base> --user <user>

# 4. Evaluate / build.
nix eval --impure --extra-experimental-features 'nix-command flakes' --json 'path:.#public' --apply attrNames
nix build  --impure --extra-experimental-features 'nix-command flakes' .#checks.x86_64-linux.mcp-logseq
nixos-rebuild build --flake .#<spice>-<base>_inner --impure
```

Then the usual deploy discipline on the host: `make switch` **and**
`make mcp-restart` before starting an OpenCode session, so the new agent and its
MCP instances register.

## 6. Worked example — `green-cubanelle`

- `common = { spiceNamespace = "green"; systemBaseName = "cubanelle"; }`
- child: `ai-/green-/cubanelle`; branch `agent/green/cubanelle`
- mount prefix: `/usr/local/green-/cubanelle/…` (+ `~/.bookmarks/shared-configs/Unix_dotfiles`)
- provisioner: `green-inner-conv-plat-prov`; summarizer `summ-green-inner-conv-plat-prov`
- allocate one Logseq port pair (e.g. next free pair after the green
  `18124/18125`), register the profile + ports, extend the oracle
- inner home catalog: `catalogs.green-cubanelle`
- deployment: `docker-compose.green-cubanelle.yml`,
  `.env.green-cubanelle`, `configs/runtime-home-bridge/green-cubanelle.json`

Nothing in the *mechanism* (tasks, gates, bootstrap) changes — only declarations
and allocations.

## 7. Open questions

1. **Is `<spice>` darkGreen-class?** Does `green` grant its agents the inner
   writer (full wiring) or is it a plain container (no `-inner-conv-plat-prov`)?
   This is the load-bearing decision.
2. **Persona genericity.** Generalize the green provisioner persona into one
   shared persona, or duplicate per namespace? (Recommend: one shared persona
   for the derived name.)
3. **Oracle shape.** One combined `checks/mcp-logseq` oracle (count grows per
   namespace) vs a per-namespace check. (Recommend: per-namespace, so adding a
   machine does not churn a global count.)
4. **Port allocation.** Who owns the Logseq port range for `<spice>`? A small
   allocator/registry comment in `mcp.nix` would prevent collisions.
5. **Catalog source of truth.** Keep bridge catalogs in
   `lib/runtime-home-bridge` (current) or move them next to the machine?
