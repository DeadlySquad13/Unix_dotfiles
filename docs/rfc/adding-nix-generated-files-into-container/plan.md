# Implementation plan — host-local generated project configs on @salt

- **Status:** Proposed (plan for [`README.md`](./README.md))
- **Date:** 2026-11-17
- **Owner:** operator
- **Decision:** Variant 1 — generate the project configs locally on `@salt`,
  keep the generated paths out of Syncthing, and mount the salt generation root
  into the container via `shared-scripts`.
- **Target:** `@creamsoda` (synced sources) → `@salt` (generator + container
  host) → `darkGreen-tangerineDream-green` container.

This plan does **not** use a cream-side artifact bundle or a foreign-store
remap. Sources sync; generated project-config paths are local to each host.

## Preconditions

- Work on the real hosts:
  - `@salt`: Home Manager, Syncthing, Docker, Nix, `_scripts`.
  - `@creamsoda`: Syncthing and the project source trees.
- The analysis sandbox has no `git`, `docker`, `pixi`, or `jq`; `nix` and
  `python3` are available. Do not assume the sandbox can run the E2E.
- Salt Syncthing root: `/zsalt/shared-/@creamsoda/Projects`.
- Salt generation root (outside the synced tree):
  `~/.local/share/agent-project-configs`.
- Salt manifest (outside the synced tree):
  `~/.local/state/agent-project-configs/manifest.json`.
- `@creamsoda` remains the single writer of the non-generated synced content.

---

## Phase 0 — Host fact verification

### `@creamsoda`

```bash
cd ~/Projects/--professional/Rutube__/AutoHub
for p in _configs/*.yml _configs/Nix _scripts .envrc .env.dev \
         AutoHub.git/.git/info/exclude; do
  echo "== $p"; ls -l "$p"; readlink "$p"; readlink -f "$p" || true
done
ls -ld ~/Projects/--professional/Rutube__/_configs/Smug__/AutoHub
ls -ld ~/Projects/--professional/Rutube__/_configs/Nix__/AutoHub
ls -ld ~/Projects/--professional/Rutube__/_scripts
git -C ~/Projects/--professional/Rutube__/AutoHub ls-files \
  _configs .envrc .env.dev | head -40
git -C ~/Projects/--professional/Rutube__/AutoHub status --short | head -40
```

### `@salt`

```bash
ls -ld /zsalt/shared-/@creamsoda/Projects
ls -ld /zsalt/shared-/@creamsoda/Projects/auto-hub
readlink -f /zsalt/shared-/@creamsoda/Projects/auto-hub
readlink -f /zsalt/shared-/@creamsoda/Projects/auto-hub/CurrentTask1
ls -l /zsalt/shared-/@creamsoda/Projects/auto-hub/_configs/Main.yml

# Syncthing folder config / ignore patterns
syncthing cli config folders list 2>/dev/null || true
ls -la /zsalt/shared-/@creamsoda/Projects/.stignore 2>/dev/null || true

# Docker can create a mountpoint and the container UID can read the root.
sudo docker run --rm -v /tmp/probe:/nix/store/ffffffffffffffffffffffffffffffff-probe:ro \
  alpine:3.20 sh -lc 'ls -ld /nix/store/ffffffffffffffffffffffffffffffff-probe; echo OK'
mkdir -p ~/.local/share/agent-project-configs/probe
echo ok > ~/.local/share/agent-project-configs/probe/file
sudo docker exec <container> sh -lc \
  'id; ls -l /home/ds13/.local/share/agent-project-configs/probe/file' || true
```

**Exit criteria:** written note with the real synced path, whether `auto-hub`
is a symlink, which generated paths are Git-tracked, the Syncthing ignore
mechanism in use, Docker mountpoint support, and the container UID.

---

## Phase 1 — Shared generator module (Unix_dotfiles)

**New files:**

- `lib/project-configs/default.nix` — pure functions lifted from
  `modules/home/bookmarks/darwin/default.nix:17-173`:
  `envrc`, `defaultWorktrees`, `defaultProjects`,
  `mapProjectWorktreesToSmugConfigs`, `createProjectConfigs`,
  `projectStructures`. Output: logical path → `{ kind = "file" | "dir" |
  "text"; source | text; }`. No `home.file`, no `config`, no `source`.
  Also expose `ignorePatterns` derived from the same logical paths, so the
  Syncthing boundary cannot drift from the generator.
- `modules/home/bookmarks/projects/default.nix`:
  - options: `projectsRoot`, `rutubeProjectsRoot`, `smugRoot`,
    `nixConfigsRoot`, `scriptsRoot`, `projects`, `worktrees`, `generationRoot`,
    `manifestPath`, `writeMode` (`home.file` | `activation`),
    `syncthingFolderName`;
  - `projectsRoot` resolution: explicit value, else
    `config.services.syncthing.settings.folders.${syncthingFolderName}.path`,
    else `${home.homeDirectory}/Projects`;
  - `writeMode = "home.file"`: current Darwin behavior;
  - `writeMode = "activation"`: installs a `home.activation` script after
    `writeBoundary` that runs the salt generator (Phase 2).

**Modified files:**

- `modules/home/bookmarks/darwin/default.nix`: use the shared lib/model; keep
  Darwin-specific `.bookmarks` and `out-of-store = true`.
- `homes/x86_64-linux/ds13@salt/default.nix`: enable the new `projects`
  module, set `projectsRoot = "/zsalt/shared-/@creamsoda/Projects"` (or the
  Syncthing folder option), `writeMode = "activation"`. Do not enable
  `bookmarks/darwin`.

**Constraints:**

- `home.file` cannot target `/zsalt/...`; use the activation writer on salt.
- `lib/paths/default.nix:27-28` requires non-empty `paths` for `source`; the
  shared lib bypasses `source`.
- `lib/modules/default.nix:107-108` uses `builtins.currentSystem`; use an
  explicit `enable` + target-host check, not only `isLinux`.
- Pass worktree/suite lists as data; the current lists are incomplete.

**Checks:** add a `checks/project-configs/` fixture that asserts the logical
attrset and the `home.file` shape for a Darwin fixture. Run the narrow
bookmarks check pattern (`Makefile.bookmarks-debug`).

**Exit:** shared lib produces the same logical attrset as the old Darwin
module; `ds13@salt` evaluates with `writeMode = "activation"`.

---

## Phase 2 — Salt generation root + manifest

**New file:** `scripts/project-configs-salt.py` (or a `writeShellApplication`
package).

Input JSON from the Nix module:

```json
{
  "syncthing_root": "/zsalt/shared-/@creamsoda/Projects",
  "generation_root": "/home/ds13/.local/share/agent-project-configs",
  "manifest_path": "/home/ds13/.local/state/agent-project-configs/manifest.json",
  "entries": [
    {"logical": "Projects/.../AutoHub/_configs/Main.yml",
     "kind": "file",
     "source": "Projects/--professional/Rutube__/_configs/Smug__/AutoHub/Main.yml"},
    {"logical": "Projects/.../AutoHub/_configs/Nix",
     "kind": "dir",
     "source": "Projects/--professional/Rutube__/_configs/Nix__/AutoHub"},
    {"logical": "Projects/.../AutoHub/_scripts",
     "kind": "dir",
     "source": "Projects/--professional/Rutube__/_scripts"},
    {"logical": "Projects/.../AutoHub/.envrc",
     "kind": "text",
     "text": "..."}
  ]
}
```

Algorithm:

1. For each entry, read the existing symlink at
   `<syncthing_root>/<logical>` to confirm it exists (optional; the generator
   can proceed from the model even if the link was already replaced).
2. Materialise real content at `<generation_root>/<logical>`:
   - `file` / `text`: write the file;
   - `dir`: copy dereferenced (`copytree(..., symlinks=False,
     ignore_dangling_symlinks=True)`), with cycle/depth guard and `.git`
     exclusions. For large trees (`_scripts`), prefer
     `rsync -aL --delete` or skip the copy when a tree hash is unchanged.
3. Record `{path, kind, sha256}` in the manifest; write atomically. For a
   directory, record a deterministic tree hash (sorted `relpath\0sha256`
   lines) rather than a single file hash.
4. Prune generation-root paths not present in the new manifest (only after a
   complete successful run).
5. `--check` validates the manifest and the real files; `--dry-run` prints the
   plan.
6. `--require-ignore` fails with `PROJECT_CONFIG_IGNORE_MISSING` if the
   Syncthing ignore boundary is not present (see Phase 3).

Also add Make targets:

- `project-configs-salt`
- `project-configs-salt-check`

**Validation on `@salt`:**

```bash
make project-configs-salt
find ~/.local/share/agent-project-configs -type l -print   # must be empty
python3 -m json.tool ~/.local/state/agent-project-configs/manifest.json | head -60
head -3 ~/.local/share/agent-project-configs/Projects/--professional/Rutube__/AutoHub/_configs/Main.yml
```

**Exit:** generation root has real, dereferenced files; manifest covers the 9
paths; no symlinks inside the generation root; synced tree untouched.

---

## Phase 3 — Syncthing boundary + salt-local project links (critical)

**Goal:** make `@salt` usable outside the container without syncing salt
paths to `@creamsoda`.

### 3.1 Automatic ignore boundary

Do not hand-maintain the list. Generate it from two complementary sources.

**Tier 1 — model-derived (primary).**

- `lib/project-configs` exposes `ignorePatterns` derived from
  `projectStructures` (one pattern per generated logical path).
- Both Syncthing home modules append it to
  `services.syncthing.settings.folders."rut-Projects".ignorePatterns`:
  - `homes/aarch64-darwin/apakalo@creamsoda/syncthing/default.nix`
  - `homes/x86_64-linux/ds13@salt/syncthing/default.nix`
- Add a `checks/project-configs` assertion that every generated logical path
  has a corresponding ignore pattern.

**Tier 2 — scan-based discovery (catch-all / drift check).**

Add `--discover` to the generator:

```text
walk the rut-Projects root (skip .artifact, .artifacts--processed, ai-, and
.git internals except the explicit info/exclude entry);
for every symlink:
    target = os.readlink(path)
    if target is absolute and not under a host-neutral whitelist:
        emit "/" + relpath(path, rut-Projects)
```

The rule is: **an absolute symlink under the project roots is host-specific
and must not sync.** This includes absolute targets inside the project tree,
because the root prefix differs (`/Users/apakalo/Projects` vs
`/zsalt/shared-/@creamsoda/Projects`). Relative symlinks and internal worktree
aliases (for example `Main -> AutoHub.git`) stay syncable. Keep a small
whitelist for genuinely shared absolute prefixes (`/shared/...`, `/mnt/...`)
if needed.

Apply the result in one of two ways:

- **Declarative (recommended):** compare the discovery result with the Tier 1
  list and fail the check with the extra paths, so the model is extended
  deliberately.
- **Dynamic:** write a device-local `.stignore.generated` in the folder root,
  include it from `.stignore` (`#include .stignore.generated`), and ask
  Syncthing to rescan/reload via REST/CLI. Keep the generated file out of sync.

**Verify before writing links:**

```bash
# Effective ignore list on the salt side (choose the command available on the host).
syncthing cli config folders <rut-Projects-id> ignores get
# or: curl -s -H "X-API-Key: $SYNCTHING_API_KEY" \
#   "http://127.0.0.1:8384/rest/config/folders/<rut-Projects-id>" | jq '.ignorePatterns'

# Discovery drift check (must be empty or explicitly accepted).
make project-configs-salt-check   # runs --discover and compares with Tier 1
```

If `ignorePatterns` are shared across devices, Tier 1 applies on both ends. If
the operator wants per-device behavior, use the local `.stignore` path instead
and leave the shared folder config unchanged.

### 3.2 Write the salt-local links

Extend the activation script:

1. Verify the ignore boundary (`--require-ignore`); abort if missing.
2. For each generated path (the 9 paths), replace the salt-side path with a
   symlink to the generation root. Do not touch other project files.
3. Write the manifest/state last (artifacts-first).
4. Log every replacement; support `DRY_RUN_CMD`.

The links are absolute (`/home/ds13/.local/share/...`) because the project
path and the generation root are on the same host; relative links would be
harder to keep correct across the `auto-hub` alias.

### 3.3 Verify

```bash
# Host-side structure
ls -l /zsalt/shared-/@creamsoda/Projects/auto-hub/_scripts
ls -l /zsalt/shared-/@creamsoda/Projects/auto-hub/_configs/Main.yml
readlink -f /zsalt/shared-/@creamsoda/Projects/auto-hub/_scripts
readlink -f /zsalt/shared-/@creamsoda/Projects/auto-hub/_configs/Nix
readlink -f /zsalt/shared-/@creamsoda/Projects/auto-hub/CurrentTask1/.envrc

# No write-back: wait for a sync cycle and check @creamsoda's mtimes / Syncthing log.
```

**Exit:** host project structure works; no change reaches `@creamsoda`.

**Gate:** do not proceed if the ignore boundary cannot be made reliable.

---

## Phase 4 — `shared-scripts` mount + guard

### Resolver

File:
`_scripts/_features/packages/agent-compose-mounts/src/dsomega_agent_compose_mounts/resolve.py`

- Load/validate the generation root:
  - env `AGENT_PROJECT_CONFIG_ROOT` (default
    `~/.local/share/agent-project-configs`);
  - if it is also listed in `AGENT_ARTIFACT_AUTO_MOUNT_ROOTS`, the existing
    artifact-root logic emits one same-path ro mount. Prefer this; no new
    mount class.
- Add a foreign-store/link classification:
  - symlink target under the generation root → allowed (artifact root);
  - symlink target under `/nix/store/**` and the host path exists → legacy
    same-path;
  - symlink target under `/nix/store/**` and the host path is missing →
    `MOUNT_SOURCE_MISSING` (unless the target is a `.direnv`/`nix-shell-env`
    path, which is skipped).
- Skip `.direnv/**` symlinks and `nix-shell-env` targets (host devshell state).
- Generic guard:
  - no bind with a missing source → `MOUNT_SOURCE_MISSING`;
  - `"bind": {"create_host_path": False}` on **every** resolver-emitted volume
    (git mounts already have it);
  - `TARGET_COLLISION` across declared/git/artifact-root/remap mounts.
- Payload delta (additive): `project_config_root: {root, manifest,
  generated_at}`; keep `schema_version = 1`.

### Launcher

File: `_scripts/llm.py`

- Set:
  ```text
  AGENT_PROJECT_CONFIG_ROOT=/home/ds13/.local/share/agent-project-configs
  AGENT_ARTIFACT_AUTO_MOUNT_ROOTS=...:/home/ds13/.local/share/agent-project-configs
  ```
  (append to any existing auto-mount roots).
- No extra container mount is needed; the resolver emits the generation-root
  mount.

### Checks

File: `_scripts/features.py` — add `project_configs_check` (run the generator
`--check` on salt).

### Tests

`_scripts/_features/packages/agent-compose-mounts/tests/test_resolve.py`:

- symlink under the generation root → allowed, one same-path ro mount;
- generation root missing → `PROJECT_CONFIG_ROOT_MISSING`;
- missing target under the generation root → `PROJECT_CONFIG_LINK_MISSING`;
- stale sha → `PROJECT_CONFIG_STALE`;
- host `/nix/store` path present → legacy same-path;
- host `/nix/store` path missing → `MOUNT_SOURCE_MISSING`;
- `.direnv`/`nix-shell-env` skipped;
- all emitted binds have `create_host_path: false`;
- no duplicate targets.

Update the existing `/nix/store` tests (`:707-716`, `:1358-1376`) to use a
real fixture or assert the fail-closed error.

**Validation:**

```bash
cd /usr/local/darkGreen-/tangerineDream/_scripts
pixi run --environment agent-compose-mounts --manifest-path _features \
  pytest _features/packages/agent-compose-mounts/tests -q
```

**Gate:** the resolver change can ship behind
`AGENT_PROJECT_CONFIG_ROOT` unset (legacy behavior) until the host links are
verified.

---

## Phase 5 — End-to-end verification

### Host (no container)

```bash
cd /zsalt/shared-/@creamsoda/Projects/auto-hub/CurrentTask1
ls -l ../_scripts ../_configs .envrc
readlink -f ../_scripts ../_configs/Nix .envrc
nix develop --command true    # or the project's normal entry point
```

### Container

```bash
sudo docker exec <container> sh -lc '
  for p in /_configs/CurrentTask.yml /_configs/Main.yml /_configs/Nix/flake.nix \
           /_scripts /.envrc /AutoHub.git/.git/info/exclude; do
    echo "== $p"; ls -l "$p"; readlink -f "$p"; stat -c "%F %s" "$p"; head -3 "$p"
  done
  findmnt -T /home/ds13/.local/share/agent-project-configs
  nix --version
'
```

On the host, inspect the effective fragment:

```bash
cat <project_root>/.aiassist-run/docker-compose.agent.effective.yml
```

- the generation-root mount exists and is ro;
- every emitted bind has `create_host_path: false`;
- no missing-source bind remains.

**Exit:** A35–A45 pass; host and container both resolve the project structure.

---

## Phase 6 — ADR R8

Publish a new shared architecture revision superseding R6. It should contain:

- **D20 — Generic source-existence invariant.** No emitted bind with a missing
  host source; every resolver-emitted volume uses `create_host_path: false`;
  missing source → `MOUNT_SOURCE_MISSING`.
- **D21 — Host-local generated project configs.** Sources sync; generated
  project-config paths are excluded from Syncthing on both ends and generated
  locally on each host. `@creamsoda` keeps its Darwin generator; `@salt` runs
  the adapted generator.
- **D22 — Salt generation root.** Stable, real, dereferenced files under
  `~/.local/share/agent-project-configs`; manifest under
  `~/.local/state/agent-project-configs`; no absolute store links.
- **D23 — Salt-local project tree links.** Only the ignored generated paths are
  replaced; the generator verifies the ignore boundary and fails closed
  (`PROJECT_CONFIG_IGNORE_MISSING`).
- **D24 — Container mount.** The generation root is an `auto-mount` artifact
  root; the resolver emits one same-path ro mount; existing `/app`,
  `/_configs`, `/_scripts` mounts resolve the links.
- **D25 — Exclusions.** `.direnv`/`nix-shell-env`/platform closures not
  mounted; credentials excluded; data-only.
- **D26 — Rollout/rollback.** Generator on `home-manager switch` + explicit
  Make target; rollback by removing the ignore, the links, and the generation
  root.

Acceptance A35–A45.

**Process:** new shared revision linked with `supersedes` to R6; human gate; do
not edit R6 in place.

---

## Phase 7 — Optional: host-neutral generation (remove the ignore)

The durable fix is to generate host-neutral content on `@creamsoda`:

- real files for `.yml`, `.envrc`, `.env.dev`, `.git/info/exclude`;
- real directory copies (or relative links with an allowed source root) for
  `_configs/Nix` and `_scripts`.

Then both hosts work from the synced tree without local overrides, and the
Syncthing ignore/salt links can be removed. This is not the blocking fix
because it changes the `@creamsoda` generator and the synced tree content, and
requires proving the relative layout / extending the resolver's allowed roots.

---

## File-touch summary

| Area | Files |
| --- | --- |
| Shared generator | new `lib/project-configs/default.nix`, new `modules/home/bookmarks/projects/default.nix`, `modules/home/bookmarks/darwin/default.nix`, `homes/x86_64-linux/ds13@salt/default.nix` |
| Salt generator | new `scripts/project-configs-salt.py` (or package), `Makefile*` |
| Syncthing boundary | `homes/aarch64-darwin/apakalo@creamsoda/syncthing/default.nix`, `homes/x86_64-linux/ds13@salt/syncthing/default.nix` |
| shared-scripts | `_scripts/_features/packages/agent-compose-mounts/src/dsomega_agent_compose_mounts/resolve.py`, `tests/test_resolve.py`, `README.md`; `_scripts/llm.py`, `_scripts/features.py` |
| Docs | this directory, ADR R8 |

## Gates and stop conditions

- **Stop** if the real synced path/alias is not confirmed.
- **Stop** if the Syncthing ignore boundary cannot be verified; do not write
  salt-local links without it.
- **Stop** if the container UID cannot read the generation root.
- **Stop** if `.direnv`/`nix-shell-env` would be mounted into the container;
  skip or regenerate on Linux.
- **Do not** write the generation root from the container.
- **Do not** edit R6 in place.

## Rollback

| Phase | Rollback |
| --- | --- |
| 1 | Revert the shared module/lib and the salt home enable. |
| 2 | Delete the generation root and manifest; disable the activation. |
| 3 | Remove the salt-local links, then remove the Syncthing ignore (order matters: restore cream links first or re-sync). |
| 4 | Unset `AGENT_PROJECT_CONFIG_ROOT` / remove the auto-mount root; revert the resolver. |
| 5 | Revert the launcher env. |
| 6 | Do not publish R8. |
| 7 | Re-run the previous generation and restore the old links. |

No phase touches the Nix store or the synced source content.
