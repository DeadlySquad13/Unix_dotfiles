# Harness task collection (`tasks/harness/`)

The `harness` invoke collection implements the agent child-flake lifecycle from
ADR 0006 §3 / ADR 0007 D4/D5/D6. It replaces the former shell scripts
(`scripts/bootstrap-child-flake.sh`, `scripts/merge-harness.sh`); the
`/merge-harness` and `/bootstrap-child-flake` opencode commands and the
`make harness-*` targets are thin wrappers around these tasks.

Run from the host in the real parent repo:

```sh
invoke --search-root=./tasks harness.bootstrap [--dry-run]
invoke --search-root=./tasks harness.merge --dry-run
invoke --search-root=./tasks harness.merge
invoke --search-root=./tasks harness.merge --promote
invoke --search-root=./tasks harness.classify
invoke --search-root=./tasks harness.selfcheck
```

## Tasks

- `bootstrap` — create the agent child checkout at `ai-/<spice>-/<agent>` as a
  blobless partial clone with a sparse working tree containing only the agent's
  two `_inner/**` paths. Never deletes an existing checkout (moves it aside to
  `.bak-<ts>`).
- `merge` — fetch the child, verify the delta is bounded to the inner trees,
  merge in a reviewable state (`--no-commit --no-ff`), stop at the host gate,
  commit, and derive promotion targets. Never auto-resolves; never pushes.
- `classify` — print the merged classification map and derived layout paths.
- `selfcheck` — validate the classification map and derived paths (no git, no
  writes); exits non-zero on error.

## Files

- `classify.json` — classification → selector map. Declares the bounded delta
  (`**/systems/*/*_inner/**` ∪ `**/homes/*/*_inner/**`), the child scaffolding
  that must never merge back (`flake.nix`, `flake.lock`, `lib/inherit/**`), and
  the layout map used to derive propagation targets at run time.
- `classify.override.json` — optional host-local overrides, deep-merged over
  `classify.json` (empty object = no overrides). Keep this file **empty** in the
  parent: overrides are for a host's local policy, not shared state.

## Layout map

One child repo per agent at `ai-/<spice>-/<agent>` (the spice directory keeps
its suffix, e.g. `ai-/darkGreen-/tangerineDream-green`). The editable `_inner`
surface maps onto the outer (image-baked) surface:

| inner (editable, in-container) | outer (image) |
| --- | --- |
| `systems/x86_64-linux/<spice>-<agent>_inner/` | `systems/x86_64-docker/<spice>-<agent>/` |
| `homes/x86_64-linux/<user>@<spice>-<agent>_inner/` | `homes/x86_64-linux/<user>@<spice>-<agent>/` |

e.g. for the green agent:

- `systems/x86_64-linux/darkGreen-tangerineDream-green_inner` →
  `systems/x86_64-docker/darkGreen-tangerineDream-green`;
- `homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green_inner`
  → `homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green`.

Only *systems* move from the inner platform (`x86_64-linux`) to the outer
platform (`x86_64-docker`); homes keep the linux platform and only lose the
`_inner` suffix. Everything else is derived from the path layout of the merged
delta — there is deliberately **no hand-maintained registry** of targets.
