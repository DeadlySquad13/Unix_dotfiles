# ADR 0006: Agent child-flake inheritance and repository policy

- Status: Proposed — to be marked Accepted when the implementation in
  [the RFC](../rfc/agent-child-flake-inheritance.md) lands.
- Date: 2026-09-27
- Related: [ADR 0001](0001-runtime-home-bridge.md),
  [ADR 0003](0003-inner-system-inner-home.md),
  [RFC: Hybrid child-flake inheritance](../rfc/agent-child-flake-inheritance.md)

## Context

Containerized agents must be able to exercise the full power of Nix —
modifying harness, system, and home configuration and switching to it live —
without touching the host, and with the fastest possible iteration loop. The
current workflow rebuilds the Docker image for any flake-level change: stop the
session → edit the parent repo → `nix build .#dockerConfigurations.<system>` →
`docker import` → start the container → resume.

Two facts about the existing deployment shape this decision:

1. The deployment repo (`@tangerineDream`) already has the in-container switch
   driver: `Makefile` `switch-nixos-inner` execs into the container, `cd`s to
   `~/.bookmarks/shared-configs/Unix_dotfiles`, and runs
   `make switch-<system>-system`, which is
   `nixos-rebuild switch --flake .#<system>_inner --impure`. The green
   target's `_inner` system/home simply do not exist yet
   ([ADR 0003](0003-inner-system-inner-home.md) defines the pattern).
2. `ai-/darkGreen-/tangerineDream-green` is already mounted into the green
   container as the in-container repo (`UNIX_DOTFILES_AI`), but it is a
   hand-maintained copypaste with an empty nested `.git` and a divergence from
   the parent (mount fix-ups) that has no merge path.

This ADR fixes the **structure and policy** for agent-owned flakes. The
[RFC](../rfc/agent-child-flake-inheritance.md) holds the implementation plan.

## Decisions

### 1. One parent flake with an explicit `public` inheritance contract

The Unix dotfiles flake (`namespace = "ds-omega"`) remains the single source of
truth. It exposes a small, deliberate surface for agent child flakes:

```nix
public = { inherit (f) lib nixosModules homeModules darwinModules overlays packages; };
```

Child flakes consume **this** surface, not incidental passthrough attributes.

### 2. One child flake per agent at `ai-/<spice>/<agent>`

Each agent gets a thin child flake at the existing `ai-` path pattern, e.g.
`ai-/darkGreen-/tangerineDream-green`. The location is unchanged from the
current copypaste, so the deployment's `UNIX_DOTFILES_AI` mount needs no change.
The child:

- keeps `namespace = "ds-omega"` (parity is mandatory — inherited modules
  captured the parent's namespace at evaluation time);
- inherits the parent as a flake input with `follows` dedupe for
  `nixpkgs`/`home-manager`/`snowfall-lib`/`sops-nix`/`nixos-wsl`;
- inherits the full module graph
  (`systems.modules.nixos = attrValues parent.nixosModules`,
  `homes.modules = attrValues parent.homeModules`) and lib (a one-file shim
  `lib/inherit/default.nix` returning `inputs.parent.lib`);
- owns a **small editable `src`** containing only the agent's
  `_inner` system/home.

**One repo per agent, not shared.** The repo is scoped to a single
agent/container identity: its editable `src` is that agent's `_inner`
system/home, and the deployment mounts it per agent via `UNIX_DOTFILES_AI`.
Every OpenCode persona running inside the container shares that one repo (the
repo follows the *container*, not the subagent). `ai-` is a shared
*directory/namespace* that holds the per-agent checkouts (with
`ai-/templates_/spice` as the generator), **not** a shared repository. Trusted
systems (e.g. `darkGreen-tangerineDream`) mount the **full parent repo**
instead; the child-flake model applies to the restricted agents (e.g.
`darkGreen-tangerineDream-green`). Cross-agent sharing of child-level modules
is intentionally out of scope and would require a shared spice-tier flake
(`parent → spice → agent`).

### 3. The child is a repository, not a worktree — blobless partial clone + sparse

Chosen over a git worktree. A worktree's `.git` is a file pointing at a host
path, so in-container `git` breaks unless the parent `.git` is mounted rw at
the host path, and it shares the parent object DB (exposing history). The
child is instead created as:

```bash
git clone --no-local --filter=blob:none --no-checkout --branch dev "$PARENT" "$CHILD"
# sparse-checkout init --no-cone; set the two inner paths; checkout
git remote remove origin
git switch -c agent/<spice>/<agent>
```

- **Blobless (`--filter=blob:none`)** keeps the commit graph (so merge-back is
  a normal related-history merge) while file *contents* of the parent's history
  are absent and cannot be lazily fetched (origin removed).
- **`--no-local`** is required for the filter to apply to a local source.
- **Sparse (`--no-cone`)** bounds the working tree to the agent-editable paths.

### 4. Scaffolding is untracked; only mergeable paths are committed

Child `flake.nix`, `flake.lock`, and `lib/inherit/` are bootstrap artifacts and
are kept **untracked** (`.git/info/exclude`). Consequently every commit in the
child touches only `systems/..._inner/` and `homes/..._inner/`, and merge-back
cannot accidentally import child-only scaffolding into the parent.

### 5. Merge-back is a local fetch + merge on the host

```bash
cd "$PARENT"
git fetch "$CHILD" agent/<spice>/<agent>
git checkout dev && git merge --no-ff FETCH_HEAD
nix flake check --keep-going && git push origin dev
```

No network, no push from the child, no shared object DB. Harness/shared-module
changes flow the other way: edit the parent, commit, then
`nix flake lock --update-input parent` in the child.

### 6. Host and paths

The authoritative host user is `ds13`; the parent repo is
`/home/ds13/.bookmarks/shared-configs/Unix_dotfiles` and the child is
`/home/ds13/.bookmarks/shared-configs/Unix_dotfiles/ai-/darkGreen-/tangerineDream-green`.
`ai-/` is added to the parent `.gitignore`. The deployment repo lives at
`/home/ds13/.bookmarks/shared-projects/ChronoIndex/2026/@tangerineDream`.

### 7. Security boundary policy

The child's tracked tree and declared inputs exclude `secrets/`, `.sops.yaml`,
`deploy.nodes`, unrelated hosts/users, and private inputs (see the RFC table).
The boundary is enforced by **sparse checkout + curated inputs**; it is a
*soft* filesystem boundary (see Limitations).

### 8. The in-container switch loop stays in the deployment repo

The switch driver remains `switch-nixos-inner` / `switch-<system>-system` /
`connect-nixos-inner`. This ADR adds no new switch mechanism; it only makes the
`darkGreen-tangerineDream-green_inner` target real and replaces the copypaste
with a mergeable child repo.

## Limitations

- **Soft filesystem boundary.** Consuming the parent as a flake input requires
  the parent source to be reachable where the child is evaluated. If the parent
  is mounted raw, the agent can read parent files (and, with `git+file:`, its
  history) even though its working tree is clean. A hard boundary requires a
  pruned "interface" repo or a `path:` input (no `.git`). Undecided.
- **Blobless ≠ history-free.** A blobless partial clone still carries commit
  messages and paths; only file contents are withheld. If commit messages are
  sensitive, a fully fresh repo is required and merge-back becomes patch-based.
- **Namespace coupling.** The child is hard-coupled to `ds-omega`; a namespace
  change in the parent would silently break inherited `mkIfEnabled` trees.
- **Implicit API.** The `public` surface is an interface the child depends on;
  changing it can break child flakes.
- **Sparse maintenance.** Adding a newly editable path later requires
  re-running `git sparse-checkout set`.
- **Untracked scaffolding.** The child `flake.nix`/`flake.lock` are not
  versioned, so the child bootstrap is not reproducible from git alone.
- **`parent.url` resolution.** A single URL cannot trivially resolve on both
  host and container; the policy is to evaluate/switch the child only
  in-container.
- **Only inner changes are fast.** Outer image closure changes still require a
  rebuild/import.
- **One-time reconciliation debt.** The existing copypaste's mount fix-ups must
  be ported into the parent before the copy is deleted.

## Why this was chosen (over the alternatives)

- **Over the copypaste (status quo):** the parent is the single source of
  truth; there is a real merge path; drift is eliminated (drift has already
  occurred).
- **Over a git worktree:** in-container `git` works with a self-contained
  `.git`, and a blobless clone + removed origin avoids the shared object DB.
- **Over a full parent checkout in the child:** the agent keeps a small,
  bounded working tree and context; the parent's bulk and sensitive material
  stay out of the child's `src`.
- **Over parent-as-input with the full parent `src`:** inheriting the *module
  graph* + `lib` (not the tree) is what makes a near-empty child `src`
  evaluable, so the agent can edit a leaf while still resolving the whole
  configuration.
- **Over `path:` for the parent:** `git+file:` pins a rev and integrates with
  `nix flake lock`, which `path:` does not.

## Consequences

- Adding an agent = add its `_inner` system/home to the parent, create the
  child clone at `ai-/<spice>/<agent>`, wire the deployment mount + catalog
  entry. The Fast loop is then `make switch-<system>-system` in-container.
- Any change to agent wiring requires the deployment's `make switch` /
  `make mcp-restart` discipline before starting an OpenCode session
  (as with other agent wiring changes).
- The parent `nix flake check` must stay green after every merge; the child
  adds no second lockfile for shared inputs.
- Debugging the in-container switch uses the existing deployment targets
  (`switch-nixos-inner`, `connect-nixos-inner-expect`) plus
  `home-manager build --flake .#<user>@<host>_inner`.

## Alternatives rejected

- **Full copypaste** — no merge path, guaranteed drift.
- **Git worktree** — broken in-container git (`.git` file) and shared history.
- **Parent-as-input with full `src`** — hands the agent the whole parent.
- **Submodule / subtree** — extra relationship, no bounded edit surface.
- **`path:` parent input as the default** — loses pinning; retained only as a
  boundary-strength option.
