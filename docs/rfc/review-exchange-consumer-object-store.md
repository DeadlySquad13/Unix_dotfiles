# RFC — Per-consumer object store for review-exchange materialization

- **Status:** Proposed (RFC — not an accepted ADR)
- **Date:** 2026-10-27
- **Decision owner:** operator
- **Related:** `.agents/review-exchange-v1/gitlab-implementation-plan-v2.md`
  (decision D5, §5.2; decision D4 — multi-consumer)

## Summary

The review-exchange consumer materializes the exact `base..head` code by running
`git cat-file -e` against the **shared** `rut-Projects` checkout — the `.git`
carried by Syncthing (D5). A missing OID is a hard "not materializable" flag;
consumers never fetch (D5). This works only because the producer's objects are
assumed to already be present in the synced `.git`.

This RFC proposes a small, optional improvement so a missing-OID consumer can
materialize **without touching the shared `.git`** and without a consumer-side
fetch: give each consumer a private object store.

## Motivation

Two weaknesses follow from the D5 limitation:

1. If the synced `.git` does not contain an OID (e.g. a shallow/partial clone, a
   pruned object, or an object created after the last sync), the consumer cannot
   materialize at all, and it is forbidden from fetching.
2. Treating the shared checkout's `.git` as the object source couples every
   consumer to one shared, Syncthing-carried object store.

## Proposed improvement (choose one)

- **Per-consumer alternate object store.** Point each consumer's materialize at a
  private `~/.local/state/review-exchange/objects/` alternate object directory
  (via `objects/info/alternates` / `GIT_OBJECT_DIRECTORY`), populated lazily from
  the shared checkout. Missing OIDs are copied locally per-`$HOME` (D4-correct),
  never fetched, and never mutate the shared `.git`.
- **Producer-side `git bundle` carried via the transport.** The producer writes a
  `git bundle create <baseOid>..<headOid>` alongside `message.json`
  (artifacts-first, JSON last). A consumer with a missing OID unbundles into its
  private object store, then materializes without touching the shared `.git` or
  the network.

## Non-goals

Not implementing now. This is a proposal for a later, operator-approved change;
the current producer-only-fetch limitation (D5) is accepted as-is.

## Open questions

1. Which shape is preferred — a private alternate object directory, or a
   transport-carried `git bundle`?
2. Is this needed at all, given that `rut-Projects` currently carries full `.git`
   history?
