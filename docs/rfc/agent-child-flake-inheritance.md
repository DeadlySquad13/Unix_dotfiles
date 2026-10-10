# RFC: Hybrid child-flake inheritance for agent Nix development

- Status: Proposed
- Scope: Agent development workflow; `ai-/` child flakes; in-container NixOS switch loop
- Decision owner: maintainers of the Unix dotfiles deployment
- Related: [ADR 0001](../adr/0001-runtime-home-bridge.md) (runtime-home-bridge),
  [ADR 0003](../adr/0003-inner-system-inner-home.md) (inner system/inner home),
  [ADR 0006](../adr/0006-agent-child-flake-and-repo-policy.md) (the policy this
  RFC implements)

## Summary

Give each containerized agent a **thin child flake** that inherits the parent
Unix dotfiles flake's shared surface (`lib`, `nixosModules`, `homeModules`,
`overlays`, `packages`) through a Nix input, while owning a small,
**agent-editable `src`** containing only that agent's *inner* system/home. The
child is a **blobless partial clone + sparse checkout** of the parent placed at
the existing `ai-/<spice>/<agent>` path, so changes merge back with a plain
local `git fetch && git merge` while the parent's bulk and history stay out of
the agent's tree.

This turns the current stop-rebuild-import-restart cycle into an in-container
`nixos-rebuild switch --flake .#<system>_inner`, and gives the child a clean,
bounded edit surface.

## Motivation

The green agent (`darkGreen-tangerineDream-green`, container user
`tangerineDream-green`) is delivered as a Docker image built from the parent
flake (`nix build .#dockerConfigurations.darkGreen-tangerineDream-green`) with
all modules baked in. That is the best sandboxing boundary, but iterating on
anything outside the current project is slow:

- Project-local dependencies can be handled with a project `nix-shell`.
- Config changes that live in the flake itself (harness, system/home modules,
  custom packages) currently require: stop the session → edit the parent repo →
  rebuild the image → import it → start the container → resume the session.

The deployment repo (`@tangerineDream`) already contains most of the machinery
for the alternative:

- `docker-compose.darkGreen-tangerineDream-green.yml` already bind-mounts
  `${UNIX_DOTFILES_AI}` (which resolves to
  `${BOOKMARKS}/shared-configs/Unix_dotfiles/ai-/darkGreen-/tangerineDream-green`)
  into the container at
  `/usr/local/darkGreen-/tangerineDream-green/_configs/Unix_dotfiles`.
- The deployment `Makefile` already has `switch-nixos-inner`, which
  `docker exec`s into the container, `cd`s to
  `~/.bookmarks/shared-configs/Unix_dotfiles`, and runs
  `make switch-<system>-system`.
- The parent `Makefile.ConvPlatProv-docker` already emits
  `switch-<system>-system` → `sudo nixos-rebuild switch --flake
  .#<system>_inner --impure`.

Two things are missing:

1. **`darkGreen-tangerineDream-green_inner` does not exist.** Unlike
   `darkGreen-tangerineDream` and `NikolaiGogol`, the green target has no
   `_inner` system/home pair (see [ADR 0003](../adr/0003-inner-system-inner-home.md)),
   so `make switch-darkGreen-tangerineDream-green-system` is a dead reference.
2. **The `ai-/darkGreen-/tangerineDream-green` copy is a hand-maintained
   copypaste** with no merge story, an empty nested `.git`, and a divergence
   from the parent (mount fix-ups) that must be reconciled.

## Goals

- Fastest possible iteration: edit Nix inside a running agent container and
  switch immediately, without rebuilding/importing the image.
- The agent must **not** be handed the whole parent flake (it is large,
  complex, and contains sensitive material).
- Merge child → parent must be simple and **local** (no network round-trip).
- Minimize exposure of the parent's git history/blobs to the agent.
- Reuse the existing `ai-/<spice>/<agent>` layout.

## Non-goals

- Replacing the Docker image as the sandboxing boundary.
- Giving the agent access to `secrets/`, `.sops.yaml`, deploy-rs nodes, or
  unrelated hosts' systems/homes.
- Supporting in-container commits that require network access.
- A generic multi-parent composition system; this is a single-parent model.
- Making the parent's *outer* image changes fast — those still require an image
  rebuild.

## Design

```text
                        inherits outputs (flake input, git+file:)
   ai-/darkGreen-/tangerineDream-green   --------------------------->   parent Unix_dotfiles
   (child flake, sparse src)                                          (single source of truth)
      |                                                                     |
      | editable src (only)                                                  | outer image baked
      |   systems/x86_64-linux/darkGreen-tangerineDream-green_inner/         | from
      |   homes/.../tangerineDream-green@..._inner/                          | .#dockerConfigurations.<sys>
      |                                                                     v
      +---- in-container: nixos-rebuild switch --flake .#<sys>_inner ----> running container
      |
      +---- host-side merge-back: git -C parent fetch <child> && git merge
```

### 1. Parent inheritance surface

Add an explicit, reviewable contract to the parent `flake.nix` outputs. Snowfall
already exports these attributes; the `public` attrset makes the agent-facing
API intentional rather than an accident of passthrough:

```nix
outputs = inputs:
  let
    f = inputs.snowfall-lib.mkFlake rec { /* existing config unchanged */ };
  in
  f // {
    # Explicit inheritance surface for agent child flakes (see ADR 0006).
    public = {
      inherit (f) lib nixosModules homeModules darwinModules overlays packages;
    };
  };
```

The parent also gains the green `_inner` pair (Phase 1) so the child has
something to check out and edit.

### 2. Child flake

- **Location:** `ai-/<spice>/<agent>/`, i.e.
  `ai-/darkGreen-/tangerineDream-green/`. This is already the deployment's
  `UNIX_DOTFILES_AI`, so no environment change is needed for the mount.
- **`src = ./.`** — the sparse working tree.
- **Namespace parity is mandatory** (`snowfall.namespace = "ds-omega"`).
  Inherited modules are evaluated closures that captured the parent's `lib`,
  `inputs`, and namespace at parent-eval time; a different namespace makes
  `lib.ds-omega.mkIfEnabled` read an empty enable tree and collapse the config.
- **Inherit the whole module graph** (read-only) so evaluation is safe even
  when the sparse `src` omits sibling modules:

  ```nix
  systems.modules.nixos = builtins.attrValues inputs.parent.nixosModules;
  homes.modules         = builtins.attrValues inputs.parent.homeModules;
  overlays              = builtins.attrValues inputs.parent.overlays
                          ++ [ inputs.parent.inputs.nixgl.overlay ];
  ```

  Inherited module lists are appended **after** the auto-discovered
  `src/modules/**`, so a near-empty `src` is safe.
- **Lib shim:** `lib/inherit/default.nix` returns the parent's flat lib so the
  child's `lib.ds-omega` is populated:

  ```nix
  { inputs, ... }: inputs.parent.lib
  ```
- **Editable `src`** (the only tracked content): the green
  `systems/..._inner/` and `homes/..._inner/`.
- **Scaffolding** (`flake.nix`, `flake.lock`, `lib/inherit/`) is written fresh
  and kept **untracked** (`.git/info/exclude`) so it never merges back.

**One child repo per agent (not shared).** The repo is scoped to a single
agent/container identity at `ai-/<spice>/<agent>`, because its editable `src`
is that agent's `_inner` system/home and the deployment mounts it per agent
(`UNIX_DOTFILES_AI`). Every OpenCode persona running inside that container
shares the one repo. `ai-` is a shared *directory/namespace* holding the
per-agent checkouts (with `ai-/templates_/spice` as the generator template),
**not** a shared repository. Trusted systems (e.g. `darkGreen-tangerineDream`)
mount the full parent repo instead; the child-flake model is for the restricted
agents (e.g. `darkGreen-tangerineDream-green`). Cross-agent sharing of
*child-level* modules is out of scope and would require a shared spice-tier
flake (`parent → spice → agent`).

### 3. Git topology (Approach A: blobless partial clone + sparse)

Chosen over a worktree because a worktree's `.git` is a file pointing at a host
path (so in-container git breaks without mounting the parent `.git`), and
because a worktree shares the parent object DB (exposing history). A clone has
a self-contained `.git` and can be created blobless.

One-time creation on the host (as `ds13`):

```bash
PARENT=/home/ds13/.bookmarks/shared-configs/Unix_dotfiles
CHILD=/home/ds13/.bookmarks/shared-configs/Unix_dotfiles/ai-/darkGreen-/tangerineDream-green

# Remove the old copypaste (after porting its fix-ups to the parent).
# Blobless partial clone: commit graph + trees present, file contents absent.
# --no-local forces the filter for a local source (local clones ignore --filter).
git clone --no-local --filter=blob:none --no-checkout --branch dev "$PARENT" "$CHILD"
cd "$CHILD"

# Sparse: only the mergeable inner paths (root files excluded).
git sparse-checkout init --no-cone
git sparse-checkout set --no-cone \
  '/systems/x86_64-linux/darkGreen-tangerineDream-green_inner/**' \
  '/homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green_inner/**'
git checkout

# Cut origin so the agent cannot lazily fetch parent blobs
# (`git log -p` on old commits then errors instead of leaking contents).
git remote remove origin

# Scaffolding: write child flake.nix / flake.lock / lib/inherit/default.nix and
# keep them untracked.
printf '%s\n' 'flake.nix' 'flake.lock' '/lib/inherit/' >> .git/info/exclude

git switch -c agent/darkGreen/tangerineDream-green
```

### 4. Merge-back (local, no network)

```bash
# The agent commits inside the child (only the tracked inner paths change):
#   git -C "$CHILD" add -A && git -C "$CHILD" commit -m "green: <change>"

# On the host, fetch the child by filesystem path into the parent and merge.
cd /home/ds13/.bookmarks/shared-configs/Unix_dotfiles
git fetch "$CHILD" agent/darkGreen/tangerineDream-green
git checkout dev
git merge --no-ff FETCH_HEAD          # resolve conflicts if any
nix flake check --keep-going
git push origin dev
```

Because the child descends from the parent's `dev`, only the child's new
commits transfer; the scaffolding never arrives (it was never committed).
Blobless partial clones still serve merge-back correctly: the parent already
has every pre-existing blob, and the child holds the blobs it authored.

### 5. Deployment wiring

- `UNIX_DOTFILES_AI` already points at
  `ai-/darkGreen-/tangerineDream-green`; no change required for the child mount.
- Add a **read-only parent mount** for the child flake's `parent` input, under
  the per-system namespace, e.g.
  `/usr/local/darkGreen-/tangerineDream-green/_configs/Unix_dotfiles_parent`.
- Add the green runtime-home-bridge catalog mapping for the in-container repo
  symlink (the non-green `orchestrator` variant has it; the green variant does
  not):
  `{ source = "_configs/Unix_dotfiles"; target = ".bookmarks/shared-configs/Unix_dotfiles"; }`
  in `lib/runtime-home-bridge/default.nix`.
- The child's `parent.url` must resolve **in-container** (see Open questions).

### 6. Iteration loop (three tiers)

1. **Green-delta (fastest):** edit the child `src` in-container →
   `sudo nixos-rebuild switch --flake .#darkGreen-tangerineDream-green_inner --impure`
   (or `make switch-darkGreen-tangerineDream-green-system`) → validate → commit
   on `agent/...` → host merge.
2. **Harness/shared module:** edit in the parent on the host → commit → in the
   child `nix flake lock --update-input parent` (re-points the `git+file:` rev)
   → switch the `_inner` in-container to test the inherited change → merge.
3. **Outer image:** only when the *outer* closure changes (outer system/home or
   a shared module baked into the image) → `switch-spice.sh` / `make
   build-darkGreen-tangerineDream-green` → import → start → connect.

Inner-only changes skip the image rebuild entirely.

## Security boundary and limitations

The child's tracked tree and default context contain only the inner paths. The
following are excluded from the child `src` and from the child flake's declared
inputs:

| Excluded | Why |
| --- | --- |
| `secrets/` | sops ciphertext + build-time secrets |
| `.sops.yaml` | age key references (identities) |
| `deploy.nodes` in `flake.nix` | host/ssh/bootstrap key paths |
| `systems/x86_64-linux/{cake,MelisStoke,olivier}/` | unrelated hosts |
| `homes/.../{ds13@salt,ds13@cake,ds13@olivier,MelisStoke@MelisStoke}/` | unrelated users |
| `xray-config`, `mcp-logseq`, `opencode-ssh-session`, `opencode` | private/vendor inputs |
| `.git/config` + remotes | ssh remote URL |

**Limitation — the boundary is soft at the filesystem.** To consume the parent
as a flake input, the parent source must be reachable from the evaluating
environment. If the parent is mounted raw, the agent *can* read parent files
(and, with `git+file:`, its history) even though its working tree and context
are clean. A hard boundary requires either:

- a **pruned "interface" repo** containing only `lib/`, `modules/`,
  `overlays/`, `packages/`, `flake.nix`, `flake.lock` (mounted instead of the
  raw parent); or
- a **`path:` input** (no `.git`) instead of `git+file:`, which avoids history
  exposure at the cost of pinning/reproducibility.

This is left as an open decision (below).

## Alternatives considered

### Full copypaste (status quo)

`ai-/darkGreen-/tangerineDream-green` as a hand-copied tree. No inheritance, no
merge story, guaranteed drift (already observed: the copy carries mount fix-ups
absent from the parent). Rejected.

### Git worktree

Shares the parent object DB and makes merge a direct local `git merge`, but:

- a worktree `.git` is a file pointing at a host path → in-container
  `git add/commit` fails unless the parent `.git` is mounted rw at the host
  path;
- shared object DB exposes parent history to the agent.

Rejected in favour of a clone, which fixes both.

### Parent-as-input with the full parent `src`

Let the child reuse the parent tree wholesale (no sparse checkout). Simplest to
evaluate, but the agent sees the whole parent — contradicts the primary
motivation. Rejected.

### `path:` input for the parent

Live-tracks the parent working tree and avoids `.git` history exposure, but is
not reproducible across containers and triggers stale-lock/narHash churn.
Considered as a variant of the boundary decision; not the default.

### Submodule / subtree

Adds a second repository relationship to maintain and does not by itself bound
the agent's edit surface. Rejected as the primary mechanism.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Inherited module closure references namespace `ds-omega` | Enforce namespace parity in the child; assert via `make modules-system`. |
| Child eval fails because sparse `src` omits a dependency | Inherit the full module graph + lib; keep `src` to leaf targets only. |
| Parent history leak | Blobless clone + remove origin; mount a pruned interface repo or use `path:` (open decision). |
| `--filter` silently ignored on local clone | Use `--no-local` (documented above). |
| Conflict when parent `dev` advances in the same inner paths | Rebase the child branch on latest `dev` before work; merge `--no-ff`. |
| Child scaffolding accidentally merged back | Keep it untracked via `.git/info/exclude`; review merges for stray files. |
| `parent.url` path mismatch (host vs container) | Evaluate/switch only in-container; mount the parent at a stable namespace path. |
| One-time divergence in the old copypaste lost | Port the mount fix-ups to the parent before deleting the copy (Phase 0). |

## Phased implementation

### Phase 0 — Baseline and reconcile

1. Verify the parent `nix flake check` is green; record whether `ai-/` is
   tracked or untracked.
2. Port the copypaste's mount fix-ups into the parent (outer system/home):
   `system.activationScripts.fixDockerMountPermissions` into the green docker
   system (and its non-green twin), and the `/usr/local` repo symlink into the
   green home via the runtime-home-bridge catalog.

### Phase 1 — Green `_inner` + `public` contract (parent)

3. Add `systems/x86_64-linux/darkGreen-tangerineDream-green_inner/default.nix`
   (+ README), mirroring `darkGreen-tangerineDream_inner` but green-named
   (`boot.isContainer`, `users.users.tangerineDream-green`, `common =
   { spiceNamespace = "darkGreen"; systemBaseName = "tangerineDream-green"; }`).
4. Add
   `homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green_inner/default.nix`.
5. Add the `public` contract to `flake.nix`; add `ai-/` to `.gitignore`.
6. Add the green catalog mapping in `lib/runtime-home-bridge/default.nix`.

### Phase 2 — Child repo (Approach A)

7. Delete the old copypaste directory; create the blobless partial clone +
   sparse checkout at `ai-/darkGreen-/tangerineDream-green` (commands in §3).
8. Write the child scaffolding (`flake.nix`, `flake.lock`, `lib/inherit/`) and
   exclude it from tracking.

### Phase 3 — Deployment wiring

9. Add the read-only parent mount and set `parent.url` accordingly.
10. Confirm `make switch-nixos-inner` now succeeds because
    `.#darkGreen-tangerineDream-green_inner` exists.

### Phase 4 — Validation

11. `nix flake check` on the parent stays green.
12. `nix eval '.#nixosConfigurations."darkGreen-tangerineDream-green_inner".config.system.build.toplevel.drvPath'` and
    `home-manager build --flake .#tangerineDream-green@darkGreen-tangerineDream-green_inner`.
13. In-container `sudo nixos-rebuild switch --flake .#darkGreen-tangerineDream-green_inner --impure`
    succeeds; `~/.bookmarks/shared-configs/Unix_dotfiles` resolves to the mount;
    `git status` works inside the container.
14. A test edit committed in-container merges into `dev` cleanly.

## Open questions

- **Boundary strength:** raw parent ro mount (soft) vs pruned interface repo vs
  `path:` input (no `.git`). Which is the default?
- **`parent.url` resolution:** `git+file://` to a stable namespace path
  evaluated only in-container, vs generating the child `flake.nix` per
  environment. Host-side evaluation of the child flake is currently out of
  scope.
- **Commit-message metadata:** a blobless clone still carries commit messages
  and paths. If commit messages are sensitive, a fully fresh repo (no shared
  history) is required — accepting patch-based merge-back.
- **Curation granularity:** start with "inherit everything, edit no shared
  module"; decide later which leaf modules the agent may edit live.
- **Shared spice tier:** whether several agents under one spice should share a
  child-level flake (`parent → spice → agent`) instead of duplicating modules
  across per-agent repos.
- **`ai-/templates_/spice`** and the pre-existing `NikolaiGogol_inner` home
  gap: clean up opportunistically or defer.
- **`public` contract shape:** the explicit attrset vs relying on
  flake-utils-plus passthrough.

## Non-goals

- A generic multi-flake composition framework.
- Making the agent able to modify the parent's outer image without a rebuild.
- Solving secret distribution inside containers (handled by `SOPS_AGE_KEYS` and
  the `sops-opencode` module).
- Preserving the old `ai-` copypaste as a supported artifact.
