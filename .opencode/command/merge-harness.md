---
description: Merge a bounded inner harness delta from an agent child checkout into the host parent repo, with host review gates (thin wrapper around the `harness.merge` invoke task).
agent: build
---

# /merge-harness

Host-side entry point for the `harness` invoke collection
(`tasks/harness/harness.py`, ADR 0007 D4/D5/D6). The task does the work; this
command only invokes it and reports.

Execute:

```sh
invoke --search-root=./tasks harness.merge $ARGUMENTS
```

Contract (do not change it from here):

- Steps: discover → classify → plan [gate] → merge (review-state) → host review
  [gate] → commit → separate promotion → verify → report/rollback.
- Bounded delta: only `**/systems/*/*_inner/**` ∪ `**/homes/*/*_inner/**` may
  land; anything else aborts.
- Review-state merge: `git merge --no-commit --no-ff` into the parent; print
  `git status` / `git diff --cached` and STOP for human review.
- Never auto-resolve a conflict (abort instead); never force-push.
- Promotion to the outer surface is a **separate** phase (`--promote`) over
  layout-derived targets.

Useful flags: `--dry-run --yes --promote --child --spice --agent --branch
--target`. Prefer `--dry-run` first. This command never runs `switch`.
