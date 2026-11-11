---
description: Open the newest (or a targeted) review package from the current
  project's .local-artifacts, validate it, materialize the exact base..head code,
  and begin investigation. No GitLab credentials required.
agent: review-agent
---

# /review

Investigate a `context_snapshot` published for the repository in the current
working directory. Thin wrapper around the `review-exchange` consumer tasks.

Target selection (maps to `comparison.selection` + OID matching):

- `/review`                 → newest complete `context_snapshot`.
- `/review --branch <name>` → resolve `<name>` to a full OID in the current
                              checkout; locate the package with
                              `selection == "branch"` and `headOid == <oid>`.
- `/review --range <base> <head>` → resolve both to full OIDs; locate the
                              package with `selection == "range"`,
                              `baseOid == <base>`, `headOid == <head>`.

Execute (in order; any failure stops):

    invoke review-exchange locate --publish-root ./.local-artifacts/review $LOCATE_ARGS
    invoke review-exchange validate --package <found message.json> \
        --schema ~/.config/review-exchange/review-exchange.schema.json
    invoke review-exchange materialize --context <found message.json>

`locate` scans `.local-artifacts/review/` relative to the current directory.
Matching is by full OID, never by label. If the requested OID has no package,
report the closest available `context_snapshot` and stop. The dedicated review
agent then reads the materialized `base..head` diff plus the validated context
and produces findings against committed code only.
