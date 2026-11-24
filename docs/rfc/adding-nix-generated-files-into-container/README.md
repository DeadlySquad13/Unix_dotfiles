# RFC — Host-local generated project configs on @salt, mounted into the container

- **Status:** Proposed (RFC — not an accepted ADR)
- **Date:** 2026-11-17
- **Decision owner:** operator
- **Decision (2026-11-17):** **Variant 1** — rebuild the project-config
  generator on `@salt`, resolve its roots from the Syncthing configuration, and
  make the generated project paths **host-local** so they are correct on both
  hosts without syncing back.
- **Scope:** `@creamsoda` (aarch64-darwin) → `@salt` (x86_64-linux) → the
  `darkGreen-tangerineDream-green` agent container.
- **Related:**
  - Evidence: [`docker-inspect.json`](./docker-inspect.json)
  - Accepted resolver baseline: `ai-shared-Architecture_system/AIASSIST-VOLUMES-001
    per-project agent-volume injection architecture ADR R6` (D10–D17,
    A23–A30). This design keeps the same-path rule, so R8 is a smaller additive
    revision (host-local generation + Syncthing boundary), not a
    `source != target` carve-out.
  - `_scripts/_features/packages/agent-compose-mounts/`
  - `_scripts/llm.py`, `_scripts/features.py`
  - `modules/home/bookmarks/darwin/default.nix`,
    `modules/home/bookmarks/linux/default.nix`, `lib/paths/default.nix`
  - Syncthing folder definitions in
    `homes/aarch64-darwin/apakalo@creamsoda/syncthing/default.nix` and
    `homes/x86_64-linux/ds13@salt/syncthing/default.nix`.

## Summary

The agent worktree on `@salt` is a Syncthing copy of a `@creamsoda` project.
Several project files are absolute symlinks into `@creamsoda`'s Nix store.
Those symlinks are host-specific:

- On `@salt` they are broken (the store paths do not exist).
- If `@salt` rewrites them to point at `@salt` store paths, Syncthing carries
  the salt-specific links back to `@creamsoda` and breaks it there.
- If `@salt` leaves them alone, the project does not have the expected
  structure on `@salt` and cannot be run outside the container (`../_scripts`,
  `_configs`, `.envrc` are broken).

The resolution is a **host-local generated layer**:

1. **Sources sync; generated project-config paths do not.** The Syncthing
   `rut-Projects` ignore boundary is generated automatically from the same
   project model that creates the symlinks, with a scan-based catch-all for
   `.direnv`, manual links, and new worktrees. The source trees (`Smug__`,
   `Nix__`, `_scripts`, project files) keep syncing.
2. **Each host generates its own project-config links.**
   - `@creamsoda` keeps its current Darwin behavior (store links).
   - `@salt` runs an adapted generator that writes **real files** into a stable
     salt-local generation root and **salt-local links** at the expected project
     paths. The project structure is now correct on `@salt`.
3. **`shared-scripts` mounts the salt generation root into the container**
   same-path read-only (via the existing artifact-root `auto-mount` mode). The
   container's existing `/app`, `/_configs`, `/_scripts` mounts then resolve
   the salt-local links to the real files.

No foreign-store remap is needed, and the R6 same-path rule is preserved. The
only resolver changes are a fail-closed source guard and registering the salt
generation root as an `auto-mount` artifact root.

## Environment facts (verified)

- The analysis ran inside a container on `@salt` (`hostname = salt`), so
  host-only paths such as `/zsalt/...` and `@creamsoda`'s
  `/nix/store/qzhv8lm1...-home-manager-files` were **not** visible. Host facts
  below are derived from `docker-inspect.json` and repository files.
- `git`, `docker`, `pixi`, and `jq` are **not** installed in this analysis
  environment; `nix` 2.33.3 and `python3` are.
- The container in `docker-inspect.json` is
  `AiAssistance__darkGreen-tangerineDream-green__Opencode-NeoVim-currenttask1`,
  a `docker compose run` one-off (`com.docker.compose.oneoff: "True"`) of
  service `auto-hub-project-shared-mounts`.
- The worktree is `/zsalt/shared-/@creamsoda/Projects/auto-hub/CurrentTask1`
  (bind-mounted at `/app`).
- The project root is `/zsalt/shared-/@creamsoda/Projects/auto-hub`; the
  `HostConfig.Mounts` bind `_configs` and `_scripts` from that root to
  `/_configs` and `/_scripts`, plus `AutoHub.git/.git` and the worktree.
- Syncthing direction:
  - `@creamsoda`: `~/Projects` is the `rut-Projects` folder; `.artifact` is
    **sendonly**.
  - `@salt`: `/zsalt/shared-/@creamsoda/Projects` is the `rut-Projects` folder;
    `.artifact` is **receiveonly**.
  - `rut-Projects` itself is bidirectional; this RFC adds ignore patterns for
    the generated project-config paths so they are local on both hosts.
- `docker-inspect.json` records six distinct top-level store outputs bound
  `Source == Destination`, `RW: false`, `Mode: "ro"`:
  - `qzhv8lm1...-home-manager-files` — 9 project paths (`.yml`, `_configs/Nix`,
    `.envrc`, `.git/info/exclude`);
  - four `...-source` outputs — `kamdfm9l...`, `yj1wxm9h...`, `01x5k4nl...`,
    `zi6b8an1...`;
  - one `...-nix-shell-env` — `mb3hnwcxc...`.

## Problem statement

On `@salt`, a project file such as:

```text
_configs/CurrentTask.yml
  -> /nix/store/qzhv8lm1p6aaf2w2p56xni5lzxfy7fix-home-manager-files/
       Projects/--professional/Rutube__/AutoHub/_configs/CurrentTask.yml
```

is dangling at its **first** hop: `/nix/store/qzhv8lm1...` does not exist.
The resolver does not check existence; it sees the literal string under
`/nix/store` and emits a same-path read-only bind. Because the emitted volume
does not set `create_host_path: false`, Compose's default auto-creates the host
source, so the failure is silent (empty file/dir or mountpoint placeholder).

The same broken links also make the **host** project unusable:

```text
auto-hub/CurrentTask1  (worktree)
  ..            -> auto-hub
  ../_scripts   -> auto-hub/_scripts -> /nix/store/qzhv...  (broken on @salt)
  ../_configs   -> auto-hub/_configs -> /nix/store/qzhv...  (broken on @salt)
  .envrc        -> /nix/store/qzhv...                       (broken on @salt)
```

Running `nix develop`, scripts, or any tool that expects the cream-generated
structure fails on `@salt`. Rewriting the links on `@salt` without a sync
boundary would send salt-specific targets back to `@creamsoda`.

## Root cause — three independent layers

### 1. Missing store path on the consumer host

The store name is a Darwin build output. `@salt` has its own `/nix/store` (the
container image also carries its own NixOS closure). The path is absent, and a
same-path bind cannot copy content.

### 2. A perfect store copy would still be insufficient

The project generator uses `out-of-store = true`
(`modules/home/bookmarks/darwin/default.nix:92-114`), which calls
`config.lib.file.mkOutOfStoreSymlink` (`lib/paths/default.nix:70-90`). Home
Manager's link chain for these entries is:

```text
$HOME/Projects/.../CurrentTask.yml
  -> /nix/store/<generation>-home-manager-files/Projects/.../CurrentTask.yml
  -> /nix/store/<hm-wrapper>-hm_<name>
  -> /Users/apakalo/Projects/.../CurrentTask.yml   (out-of-store final hop)
```

`-home-manager-files` and the `hm_*` wrappers are **input-addressed**
derivations; their hashes are not reproducible on `@salt`. Even if the entire
`-home-manager-files` output were copied, the final hop still points to
`/Users/apakalo/...`, which never exists on Linux.

### 3. The generated paths are host-specific and shared by Syncthing

The project tree is synced bidirectionally. A generated link is correct on
exactly one host. There is no host-neutral content in the link unless the link
is replaced with real files or relative links. Therefore the generated paths
must be either host-neutral or **excluded from sync and generated locally on
each host**.

## Chosen architecture — host-local generated layer

```text
@creamsoda                                      @salt
──────────                                      ─────
~/Projects                                       /zsalt/shared-/@creamsoda/Projects
   │  sources sync (Smug__/Nix__/_scripts/…) ──► │
   │  generated project-config paths IGNORED ──► │  (both directions)
   │                                              │
   └─ Darwin generator                           └─ adapted salt generator
        writes cream store links                      reads the synced sources
        at the project paths                          writes real files to:
                                                       ~/.local/share/agent-project-configs/
                                                     writes salt-local links at the
                                                     project paths (ignored by Syncthing)
                                                              │
                                                              │ shared-scripts:
                                                              │ register generation root
                                                              │ as auto-mount artifact root
                                                              ▼
                                                     container:
                                                       <generation-root>:<same-path>:ro
                                                       /_configs, /_scripts, /app resolve
```

### 4.1 Syncthing boundary: sources sync, generated paths are local

Add the generated project-config paths to the `rut-Projects` ignore patterns on
**both** ends:

- `/--professional/Rutube__/AutoHub/_configs/*.yml`
- `/--professional/Rutube__/AutoHub/_configs/Nix`
- `/--professional/Rutube__/AutoHub/_scripts`
- `/--professional/Rutube__/AutoHub/.envrc`
- `/--professional/Rutube__/AutoHub/.env.dev`
- `/--professional/Rutube__/AutoHub/*/.envrc`
- `/--professional/Rutube__/AutoHub/AutoHub.git/.git/info/exclude`

The exact prefix depends on the real synced path (`auto-hub` may be a symlink
to `--professional/Rutube__/AutoHub`; Phase 0 resolves it). The patterns must
cover the **real** paths, not the alias.

Consequences:

- The generated links are **never sent** in either direction.
- Each host's generator owns its local generated links.
- The source trees (`Smug__`, `Nix__`, `_scripts`, project files) continue to
  sync normally.
- A new host/device must run its generator to create the local generated paths;
  they will not arrive via Syncthing.

If the Syncthing folder `ignorePatterns` option is shared across devices (it
is part of the folder config), adding the same patterns on both ends is the
simplest and most robust. If the operator prefers per-device patterns, use a
local `.stignore` on `@salt` with the same list.

#### 4.1.1 Automatic boundary generation

Do **not** hand-maintain the list. There are two complementary automatic
mechanisms.

**Tier 1 — declarative, from the generator model (primary).**

The shared `lib/project-configs` model already knows every path it generates.
Expose a derived list:

```nix
projectConfigIgnorePatterns =
  map (entry: "/" + entry.logicalPath) (projectStructures { ... });
```

The Syncthing home modules on both hosts append that list to
`services.syncthing.settings.folders."rut-Projects".ignorePatterns`:

```nix
ignorePatterns = [
  "/ai-"
  ".local-artifacts"
  "/.artifacts--processed"
] ++ config.lib.ds-omega.projectConfigIgnorePatterns;
```

This is automatic: add a project/worktree to the model and the ignore list
updates on both hosts at the next `home-manager switch`. It is exact and has no
scanning false positives.

**Tier 2 — scan-based catch-all (discovery / drift check).**

Not every host-specific symlink comes from the model (`.direnv`, manual links,
new worktrees). Add a discovery mode to the generator:

```text
walk the rut-Projects root (skip .artifact, .artifacts--processed, ai-, .git
internals except the explicit info/exclude entry);
for every symlink:
    target = os.readlink(path)
    if target is absolute and not under a host-neutral whitelist:
        emit "/" + relpath(path, rut-Projects)
```

The rule is: **an absolute symlink under the project roots is host-specific
and must not sync.** Absolute targets inside the project tree are host-specific
too, because the root prefix differs (`/Users/apakalo/Projects` vs
`/zsalt/shared-/@creamsoda/Projects`). Relative symlinks and internal worktree
aliases (for example `Main -> AutoHub.git`) stay syncable. Keep a small
whitelist for genuinely shared absolute prefixes (`/shared/...`, `/mnt/...`)
if the operator has symlinks that are valid on both hosts.

Apply the discovered list in one of two ways:

- **Declarative (recommended):** compare the discovery result with the Tier 1
  list and fail the check with the extra paths, so the model is extended
  deliberately. No dynamic Syncthing state.
- **Dynamic:** write a device-local `.stignore.generated` in the folder root,
  include it from `.stignore` (`#include .stignore.generated`), and ask
  Syncthing to rescan/reload (REST/CLI). Use this if the operator wants the
  catch-all to apply without editing the Nix model. Keep the generated file
  out of sync (it lives next to `.stignore`, which Syncthing does not sync).

**Fail-closed verification before writing salt links.**

The salt generator must verify that every path it is about to replace is
covered by the *effective* ignore list (Tier 1 + Tier 2). If not, it aborts
with `PROJECT_CONFIG_IGNORE_MISSING`. This is the single safety gate that
prevents salt paths from leaking to `@creamsoda`.

**New worktrees/projects.**

- `.envrc` patterns use a wildcard (`*/.envrc`) so new worktrees are covered
  automatically.
- `_configs/*.yml`, `_configs/Nix`, `_scripts`, and the git exclude come from
  the model; add new worktrees to the model (or let the Tier 2 discovery
  report them). The shared module should derive worktrees from the actual tree
  where possible, not only from the hard-coded list.

### 4.2 Shared generator module (Unix_dotfiles)

Extract the host-independent project model from
`modules/home/bookmarks/darwin/default.nix:17-173` into:

- `lib/project-configs/default.nix` — pure functions:
  `envrc`, `defaultWorktrees`, `defaultProjects`,
  `mapProjectWorktreesToSmugConfigs`, `createProjectConfigs`,
  `projectStructures`.
- `modules/home/bookmarks/projects/default.nix` — enabled on both Darwin and
  Linux, with:
  - `projectsRoot` (Darwin `~/Projects`; salt
    `/zsalt/shared-/@creamsoda/Projects`, resolved from the Syncthing folder
    option when possible);
  - `rutubeProjectsRoot`, `smugRoot`, `nixConfigsRoot`, `scriptsRoot`;
  - `generationRoot` (salt-only; default
    `~/.local/share/agent-project-configs`);
  - `writeMode` (`home.file` on Darwin; `activation` on salt);
  - `projects`, `worktrees`;
  - `syncthingFolderName` (default `"rut-Projects"`).

The Darwin module keeps its current behavior (store links) by using
`writeMode = "home.file"`. The salt module uses `writeMode = "activation"` to
write the generation root and the salt-local links.

Important constraints found in the code:

- `home.file` can only target paths under `$HOME`. The salt generator uses an
  activation writer; do not add `home.file."/zsalt/..."` keys.
- `lib/paths/default.nix:27-28` requires `config.lib.${namespace}.paths` to be
  non-empty for `source`; the shared lib bypasses `source` and uses entry
  descriptors directly.
- `lib/modules/default.nix:107-108` uses `builtins.currentSystem` for
  `isDarwin`/`isLinux`, which is the **evaluation** host, not the target. The
  new module uses an explicit `enable` plus a target-host check.
- The Darwin worktree/suite lists are incomplete for the real tree
  (`.agents/review-exchange-v1/worktree-structure.md:4-20`); pass them as data.

### 4.3 Salt generation root

The salt generator writes **real, dereferenced files** to:

```text
~/.local/share/agent-project-configs/
  Projects/--professional/Rutube__/AutoHub/
    _configs/CurrentTask.yml
    _configs/CurrentTask1.yml
    _configs/Epic.yml
    _configs/Main.yml
    _configs/Release.yml
    _configs/Review.yml
    _configs/Nix/...            # real directory, dereferenced
    _scripts/...                # real directory, dereferenced
    .envrc                      # real text file
    AutoHub.git/.git/info/exclude
    CurrentTask1/.envrc
    ...
```

- The layout mirrors the **logical project paths** exactly. This is what makes
  the salt-local links simple and predictable.
- Copy dereferenced (`cp -aL` / `copytree(symlinks=False)`); the generation root
  must contain no absolute store symlinks and no `/Users/apakalo` paths.
- Set `0755` dirs / `0644` files so the container UID can read them.
- Write a manifest for verification.
- Never write the synced `rut-Projects` tree.

The generator can be a Home Manager activation script on `@salt` (recommended:
reads the live Syncthing tree, no store copy of the whole project) or a Nix
derivation if reproducibility is preferred.

### 4.4 Salt-local project tree links

After the generation root is populated, the salt activation replaces the
generated paths **in the salt-local project tree** with symlinks to the
generation root:

```text
/zsalt/shared-/@creamsoda/Projects/auto-hub/_configs/Main.yml
  -> /home/ds13/.local/share/agent-project-configs/Projects/.../AutoHub/_configs/Main.yml
```

- Only the paths listed in the Syncthing ignore patterns are replaced.
- The links are salt-specific; the ignore boundary prevents them from syncing.
- The rest of the project tree is untouched.
- The host now has the expected structure:
  - `auto-hub/CurrentTask1/../../_scripts` resolves through
    `auto-hub/_scripts` → generation root `_scripts`;
  - `_configs/*.yml`, `_configs/Nix`, `.envrc`,
    `AutoHub.git/.git/info/exclude` resolve.
- The original cream links are replaced on `@salt` only; `@creamsoda` keeps its
  own generated links.

Ordering is critical:

1. Install the Syncthing ignore patterns.
2. Verify they are active.
3. Run the salt generator/links.
4. Verify no change is sent to `@creamsoda`.

The generator must refuse to write if the ignore patterns are not present
(fail closed), so a misconfiguration cannot leak salt paths to `@creamsoda`.

### 4.5 `shared-scripts`: mount the generation root into the container

Register the salt generation root as an artifact root with
`mount_mode: auto-mount`:

```text
AGENT_ARTIFACT_AUTO_MOUNT_ROOTS=/home/ds13/.local/share/agent-project-configs
```

The resolver then:

- allows every salt-local project symlink whose target is under the generation
  root;
- emits exactly one same-path read-only mount:
  `<generation-root>:<generation-root>:ro`;
- keeps the existing `_configs`, `_scripts`, `/app`, and git mounts.

Inside the container:

- `/app/CurrentTask1/.envrc` → generation root → real file;
- `/_configs/Main.yml` → generation root → real file;
- `/_configs/Nix` → generation root → real directory;
- `/_scripts` → Docker resolves the bind source to the generation root
  directory, and the mount is present same-path for any nested links;
- `AutoHub.git/.git/info/exclude` → generation root → real file.

No `/nix/store` remap is needed. The R6 same-path rule is preserved.

The resolver still needs the generic guard:

- never emit a bind whose host source does not exist →
  `MOUNT_SOURCE_MISSING`;
- set `create_host_path: false` on every resolver-emitted bind;
- skip `.direnv`/`nix-shell-env` host state;
- keep `schema_version = 1`; add an optional `project_config_root` payload
  section (generation root, manifest, `generated_at`).

The manifest (schema 1) is for verification and runbook, not for remapping:

```json
{
  "schema_version": 1,
  "generated_at": "2026-11-17T12:00:00Z",
  "generator": "unix-dotfiles/project-configs@1",
  "source_host": "@salt",
  "syncthing_root": "/zsalt/shared-/@creamsoda/Projects",
  "generation_root": "/home/ds13/.local/share/agent-project-configs",
  "covered_paths": [
    "Projects/--professional/Rutube__/AutoHub/_configs/Main.yml",
    "Projects/--professional/Rutube__/AutoHub/_configs/Nix",
    "Projects/--professional/Rutube__/AutoHub/_scripts",
    "..."
  ],
  "entries": [
    {
      "path": "Projects/--professional/Rutube__/AutoHub/_configs/Main.yml",
      "kind": "file",
      "sha256": "..."
    }
  ]
}
```

The resolver can use `generation_root` to validate the mount source and
`covered_paths` to reject unexpected links.

### 4.6 Exclusions and host-specific state

- Host `.direnv` state is build state, not project config. Skip `.direnv/**`
  symlinks in the resolver (and do not copy them into the generation root).
  This removes the four `-source` and one `-nix-shell-env` binds from
  `docker-inspect.json`; the container can run `nix develop` against the
  synced `_configs/Nix` flake if it needs a Linux devshell.
- `nix-shell-env` and platform-specific closures are not mapped or copied.
- Do not replace credential paths.
- The salt generator must not copy `.git` internals other than the explicit
  `info/exclude` entry.

## Why this works on both sides

**On `@salt` (outside the container):**
- `auto-hub/_scripts`, `_configs`, `.envrc`, `.env.dev`,
  `AutoHub.git/.git/info/exclude` are real, readable paths.
- `nix develop`, scripts, and tools see the expected structure.
- The links are salt-local; Syncthing ignores them, so `@creamsoda` is
  untouched.

**Inside the container:**
- The project mounts (`/app`, `/_configs`, `/_scripts`, `AutoHub.git/.git`)
  bring the salt-local tree.
- The generation root is mounted same-path read-only, so every salt-local link
  resolves to a real file/dir.
- The container's own `/nix/store` is not replaced.
- The resolver preserves R6 same-path semantics; only the generation root is a
  new `auto-mount` root.

## Alternatives considered

- **Foreign-store remap (`source != target`).** It fixes the container but not
  the host project structure; the host still has broken cream links unless the
  tree is rewritten. It also needs a larger R8 carve-out. Rejected as the
  primary design.
- **Cream-side artifact bundle under `.artifact`.** Same host gap: the project
  tree still points at cream store paths; the bundle only fixes the container.
  Rejected.
- **Rewrite the synced tree without an ignore boundary.** Salt-specific links
  sync back to `@creamsoda` and break it. Rejected.
- **Host-neutral generation on `@creamsoda` (real files / relative links).**
  This is the durable elimination and is recorded as a follow-up. It requires
  materialising `_scripts`/`_configs/Nix` or proving relative-link layouts and
  possibly extending the resolver's allowed roots. It is not the blocking fix
  because it changes the `@creamsoda` generator and the synced tree content.

## Constraints

- R6 guarantees remain: same-path read-only external mounts, no arbitrary
  container targets, no credential paths, no project-root/fragment/ancestor
  exposure, fail-closed on unknown targets, no duplicate targets.
- The salt generator must not write the synced tree beyond the ignored
  generated paths, and must fail closed if the ignore boundary is absent.
- The generation root is the only new mount source; it is read-only in the
  container.
- No platform-specific closures; no `.direnv` state.
- The cream side remains the single writer of the non-generated synced content.

## Error codes (additive)

| Code | Meaning |
| --- | --- |
| `MOUNT_SOURCE_MISSING` | Any emitted bind's host source does not exist. |
| `PROJECT_CONFIG_ROOT_MISSING` | The configured generation root is absent. |
| `PROJECT_CONFIG_MANIFEST_INVALID` | Manifest missing, malformed, wrong schema, or unsafe path. |
| `PROJECT_CONFIG_LINK_MISSING` | A salt-local project link/target is missing from the generation root. |
| `PROJECT_CONFIG_STALE` | Recorded sha256 does not match the real file. |
| `PROJECT_CONFIG_IGNORE_MISSING` | The generator refused to write because the Syncthing ignore boundary is absent. |
| `TARGET_COLLISION` | Two emitted mounts share a target. |

Existing R5/R6 codes are retained.

## Acceptance criteria (A35–A45, additive to A23–A30)

- **A35** The generated project paths are in the Syncthing `rut-Projects`
  ignore patterns on both hosts; changes to them are not sent in either
  direction.
- **A36** On `@salt`, `auto-hub/_scripts`, `auto-hub/_configs`, `.envrc`,
  `.env.dev`, and `AutoHub.git/.git/info/exclude` resolve to real readable
  files/dirs **without** the container.
- **A37** The salt generation root contains no absolute store symlinks and no
  `/Users/apakalo` paths.
- **A38** The resolver allows salt-local links under the generation root and
  emits exactly one same-path ro mount of the generation root.
- **A39** In-container `readlink -f`, `stat`, and `cat` on the project paths
  succeed; `findmnt -T <generation-root>` shows the mount.
- **A40** Host store outputs that are still present on `@salt` (if any) keep
  the legacy same-path behavior; no remap is introduced.
- **A41** No emitted bind has a missing source; every resolver-emitted volume
  has `create_host_path: false`; no duplicate targets.
- **A42** `.direnv`/`nix-shell-env` host state is not mounted; a Linux devshell
  can still be produced inside the container from the synced `_configs/Nix`.
- **A43** The salt generator is idempotent and does not send changes to
  `@creamsoda` (Syncthing log / mtime check).
- **A44** A new `@creamsoda` generation changes the project symlinks; after
  Syncthing, the salt generator re-runs and the salt tree remains valid.
- **A45** `git status` in the synced tree is unchanged for tracked files (or
  the generated paths are confirmed untracked/ignored; see open questions).

## Open questions — must verify on the real hosts

1. Confirm the real synced path: is `auto-hub` a symlink to
   `--professional/Rutube__/AutoHub`, or is it a separate directory? The
   Syncthing ignore patterns and the generator paths depend on it.
2. Confirm `rut-Projects` `ignorePatterns` are shared across devices. If not,
   decide on a local `.stignore` on `@salt` vs a shared pattern.
2a. Confirm whether Syncthing reloads a `#include`d `.stignore.generated` after
    a write, or whether a REST/CLI rescan is required. If reload is unreliable,
    prefer Tier 1 (folder `ignorePatterns`) and use Tier 2 only as a drift
    check.
2b. Review the Tier 2 discovered list on the real tree. The rule (absolute
    symlink whose target escapes the synced root) should catch `.direnv`,
    generated store links, and manual external links, while leaving relative
    worktree aliases alone. Confirm there are no false positives before
    enabling dynamic apply.
3. Check whether the generated paths are tracked by Git (`git ls-files`) and
   whether replacing them with salt-local links creates `git status` noise.
4. Confirm Docker can create a mountpoint under the container's `/nix/store`
   (not needed for the generation root, but for any residual store mounts).
5. Confirm the container UID can read `~/.local/share/agent-project-configs`.
6. Decide whether the salt generator runs on `home-manager switch`, a systemd
   user timer, or on demand via a Make target.
7. Confirm the ADR revision number (R8) and the human gate.

## Risks

- **Ignore boundary failure:** if the Syncthing ignore patterns are missing or
  incomplete, salt-local links can sync back to `@creamsoda`. The generator
  must verify the boundary and fail closed.
- **New worktrees/projects:** the ignore patterns and generator data must cover
  them; otherwise the new paths are not host-local.
- **Git noise:** if generated paths are tracked, replacing them with salt-local
  links may show as modifications. Prefer untracked/ignored paths or
  host-neutral real files for tracked ones.
- **Staleness:** changes on `@creamsoda` to the source trees arrive via
  Syncthing, but the salt generation root must be re-run to reflect them.
- **`.direnv`/`nix-shell-env`:** must be skipped; a Darwin closure must not be
  mounted into the Linux container.
- **Container store:** the generation root mount is under `$HOME`, not
  `/nix/store`; the container's own store remains intact.

## Reversibility

- Remove the salt-local links and the generation root; re-run the cream links
  or wait for Syncthing if the ignore is removed.
- Remove the generation root from `AGENT_ARTIFACT_AUTO_MOUNT_ROOTS`.
- Revert the Syncthing ignore patterns.
- No data migration; the synced source tree is untouched.

## References

- `docs/rfc/adding-nix-generated-files-into-container/docker-inspect.json`
- `docs/rfc/review-exchange-consumer-object-store.md` (RFC style precedent)
- `.agents/review-exchange-v1/naming-artifact-folders.md`
- `.agents/review-exchange-v1/worktree-structure.md`
- `_scripts/_features/packages/agent-compose-mounts/` (README + `resolve.py`)
- `_scripts/llm.py`, `_scripts/features.py`
- `modules/home/bookmarks/darwin/default.nix`,
  `modules/home/bookmarks/linux/default.nix`, `lib/paths/default.nix`,
  `lib/modules/default.nix`
- Logseq: `ai-shared-Architecture_system/AIASSIST-VOLUMES-001 per-project
  agent-volume injection architecture ADR R6`.

See [`plan.md`](./plan.md) for the phased implementation, file touch points,
validation commands, and gates.
