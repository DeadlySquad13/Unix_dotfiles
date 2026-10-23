---
description: Create the agent child-flake checkout (blobless sparse clone) via the `harness.bootstrap` invoke task.
agent: build
---

# /bootstrap-child-flake

Host-side preparation step for the `harness` invoke collection
(`tasks/harness/harness.py`, ADR 0006 §3 / ADR 0007 D8). It creates the
per-agent child repo at `ai-/<spice>-/<agent>` as a blobless partial clone with
a sparse working tree containing only the agent's two `_inner/**` paths.

Execute:

```sh
invoke --search-root=./tasks harness.bootstrap $ARGUMENTS
```

Contract (do not change it from here):

- Never deletes an existing checkout: it is moved aside to `.bak-<timestamp>`.
- `origin` is removed and child scaffolding (`flake.nix`, `flake.lock`,
  `lib/inherit/`) is excluded via `.git/info/exclude`, so it can never merge
  back.
- Does not write the scaffolding and does not run `switch`; the child flake is
  generated in-container against the read-only parent mount.

Useful flags: `--dry-run --parent --spice --agent --user --branch`. Prefer
`--dry-run` first.
