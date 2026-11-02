> **SUPERSEDED** by [`gitlab-implementation-plan-v3.md`](./gitlab-implementation-plan-v3.md) — operator decisions 2026-10-27 (D6.1–D6.2, D7): per-review `materialize` output (`materialized/<messageId>/`); atomic dedup/supersession index writes (temp + rename); state-directory relocation to `<state-root>/review/` via `REVIEW_EXCHANGE_STATE_DIR`. Retained for history — **implement from v3, not from this file.**

# GitLab scope — laptop↔PC review exchange: implementation plan (v2)

> **Supersession history.** This document **supersedes** [`gitlab-implementation-plan.md`](./gitlab-implementation-plan.md) (2026-10-23 revision). It records four operator decisions made **2026-10-27** (D3.1–D3.4, §0) and rewrites the affected sections (§2, §3.4, §4.1, §5.1–§5.3, §6, §8, §9). The v1 document is retained for history and points back here; **implement from this v2.**

- **Source contract:** `.agents/review-exchange-v1/README.md` (+ `review-exchange.schema.json`, `workflow.md`, `naming-artifact-folders.md`)
- **Route:** v1 = Explorer → Planner (plan-only). v2 = **Architect** superseding plan (no code). The four decisions (D3.1–D3.4) are operator-confirmed *mechanism* changes, not user-intent changes, so Strategist is not needed. G1 still escalates on any contract-field mismatch.
- **Status:** v2 supersedes v1 (operator decisions resolved 2026-10-23). Four further operator decisions resolved 2026-10-27 (see §0 D3.1–D3.4). Implementation files (`shared-scripts`, Python `_features`, Nix tooling) are being edited **in parallel by other agents and are out of scope for this document**. G-PLAN gate closed (see §0 and §7).

**Scope:** the **gitlab** slice only — deterministic production of a `context_snapshot` on the laptop (`@creamsoda`) and consumption/validation/materialization of that package on the PC (`@salt`). `review_result`/`investigation_request` production and the return-transport consumers are **out of scope** (G6); only the return-transport **folder** is reserved here.

---

## 0. Resolved decisions (2026-10-23 + 2026-10-27) — authoritative

This is the decision log. It supersedes any conflicting wording elsewhere in this document.

| # | Decision | Resolution |
|---|---|---|
| D1 | Accept the plan as terminal deliverable | Accepted |
| Producer | Deterministic scripts vs agent+MCP | **A — deterministic scripts** (git CLI + `glab api`; no `zereight` MCP) |
| D2.1 | Transport folders | **Per-top-level-folder simplex pairs** (see §2): Projects = `rut-Projects_artifacts` (`Projects/.artifact` raw, @creamsoda→@salt) + `Projects/.artifacts--processed` (processed, @salt→@creamsoda); Documents = `rut-Documents_artifacts` (`Documents/.artifacts` + `Documents/.artifacts--processed`). Plural `.artifacts` everywhere except legacy `Projects/.artifact`. In scope: the Projects pair. |
| D2.2 | JSON Schema validator | **`check-jsonschema`** (draft 2020-12 + `format` on by default) |
| D2.3 | `reviewId`/`messageId` naming | **Proposed default** — `reviewId` = comparison identity (`<repo-id>-<baseOid[0:12]>..<headOid[0:12]>`), `messageId` = per-message identity (`ctx-<reviewId>-<epochMillis>-<uuid4[0:8]>`) |
| D2.4 | `agent:` for `/review` | **Dedicated review agent** (new definition); must not overlap delivery agents (incl. `build`) |
| Arch | Layering | **3-layer**: Python `_features` core → `shared-scripts` invoke wrapper → thin TypeScript tools (see §2) |
| Arch | Script language | **Python (invoke)**; no shell scripts. Git plumbing via `git` CLI; GitLab via `glab api`; JSON via Python stdlib. |
| Naming | Authority | **`[[SUITE]]`** (the `--`/modifier convention). Referenced, not re-verified here (kbn agents own it). |
| Symlink | Target form | **Absolute** — the reused `artifact-aggregator` resolves via `.resolve()`. |
| Ignore | artifact-dir sweep | `rut-Projects` `ignorePatterns` (both hosts): **`.local-artifacts`** (unanchored → project-local dirs at any depth) and **`/.artifacts--processed`** (root-anchored → `Projects/.artifacts--processed`). `Projects/.artifact` (raw mirror) is auto-excluded as a nested Syncthing folder. Documents pair is out of scope. |
| Consumer | `--out-dir` default | `~/.local/state/review-exchange/materialized/` (PC-local, non-synced) |
| **D3.1** | **Drop the staging hop** | **Remove `~/.local/state/review-exchange/staging/`.** The producer writes directly into the final transport location, preserving "artifacts first, `message.json` last" (JSON presence = readiness) plus the consumer's SHA re-validation + retry. Rationale: the consumer (`locate`/`validate`) already treats a package as complete only when `message.json` parses AND every artifact SHA-256/sizeBytes matches, so partial-sync is already handled; a separate non-synced staging dir is redundant belt-and-suspenders. |
| **D3.2** | **Transport folder name** | **`review`, not `review-exchange`** — `naming-artifact-folders.md` already settled this: `.local-artifacts/review/` (raw) and `.artifacts--processed/review/` (processed). The string `review-exchange` is retained **only** for the contract dir (`.agents/review-exchange-v1/`), the Python package, the invoke task name, the TS tool (`review-exchange.nix`), and machine-local state/config — **never** as a synced transport folder. |
| **D3.3** | **Drop `repo-map.json` path mapping** | **Remove** the per-host `repository.id → checkout` config entirely. The consumer runs **from inside** the project/worktree and uses relative paths: package at `./.local-artifacts/review/` (project-local symlink → the centralized mirror, created by the artifact-aggregator `move → mirror → symlink-back` and recreated by `restore.py` on the receiving host); git checkout `.` (cwd); containment root `.` (cwd). Rationale: `.local-artifacts` is already project-local on both hosts via the aggregator symlink, so a path lookup is pure indirection. **New fact:** `rut-Projects` carries `.git`, so the OIDs are present in the synced checkout. `repository.id` + `displayName` stay in the payload but **only as identity** (stable `reviewId`, findings attribution, dedup/supersession), never for path resolution. `validate` performs an **identity consistency check** instead of a path lookup. |
| **D3.4** | **`/review` command location** | **Generic harness command** at `modules/home/apps/ai-assistance/opencode/commands/review.md` (sibling of `commands/test.md`), **not** project-local `.opencode/command/review.md`. It carries **no hardcoded host path** (no `/zsalt/...`), **no `--repo-map`**, and reads `./.local-artifacts/review/` relative to cwd. |
| **D4** | **Consumer = a set of filesystem-sharing hosts, not a single host** | **Transport (Syncthing) is unchanged**: `@creamsoda` ↔ `@salt` only; the sandboxes do **not** run Syncthing. **Consumption generalizes**: any host that can reach the synced `Projects` tree is consumer-capable — in practice `@salt` **plus** the AI sandboxes `@darkGreen-tangerineDream` and `@darkGreen-tangerineDream-green` (and their `_inner` counterparts), where the OpenCode review agents actually run. **Per-host consumer state**: each consumer host has its own `$HOME`, so `~/.config/review-exchange/review-exchange.schema.json` (schema copy) and `~/.local/state/review-exchange/` (dedup index + materialized output) are per-host, not shared; the synced transport (`Projects/.artifact/.../review`) is read-only to consumers. **Evidence:** sandbox homes set `deploymentHostHome = "/home/ds13"` and map `paths.projects`/`paths.shared-scripts` onto `/home/ds13/…`; their `_inner` variants resolve `projects`/`shared-scripts` via the runtime-home-bridge catalog (`zSource "shared-/@salt/Projects"`). |
| **D5** | **Producer / consumer roles (host-independent)** | **Every review-exchange run has exactly two roles, and neither is bound to a specific host.** The **producer** has git-fetch access — it can obtain missing git objects and produce the snapshot; the **consumer** has no fetch access and relies on the synced checkout for the OIDs `cat-file -e` needs. Two scenarios: **(1) remote/work** — producer `@creamsoda` (has GitLab access), consumer `@salt` or one of the sandboxes; **(2) local** — producer and consumer are agents on the **same** `@salt` (or inside a sandbox such as `@darkGreen-tangerineDream` that shares `@salt`'s filesystem). `materialize --fetch` is a **producer-side recovery knob, never a consumer capability**: it stays opt-in / default-`False`, and consumers never fetch. The shared checkout is **not** a per-consumer object store (§5.2). |

**Superseded/amended prior entries:** D2.1's folder *pairs* are unchanged, but the transport *subfolder* is `review` (D3.2). The machine-local-state list in §2 no longer contains `repo-map.json` (D3.3) or `staging/` (D3.1). G3 "repo mapping machine-local" is now satisfied by the run-from-project + identity-check model (D3.3), not by a config file. The single-consumer assumption ("PC = the only consumer") is replaced by D4: consumption is any host with filesystem access to the synced `Projects` tree; `@salt` is one such host, the AI sandboxes are others. **D5** generalizes the fetch boundary into two host-independent roles: the **producer** (has git-fetch access) and the **consumer** (no fetch access; relies on the synced checkout). In the remote/work case the producer is `@creamsoda` and the consumer is `@salt` or a sandbox; in the local case both roles run on `@salt` (or inside a sandbox sharing `@salt`'s filesystem). `materialize --fetch` is a producer-side recovery knob, never a consumer capability; consumers never fetch, and the shared checkout is not a per-consumer object store (§5.2).

---

## 1. Inputs, pinned revisions, and assumptions

### Authoritative inputs (read, not re-derived)

- `.agents/review-exchange-v1/README.md` — contract (JSON transport; 3 immutable kinds; fresh `messageId`/`supersedesMessageId`; no credentials/paths/URLs/commands in payload; full OIDs; committed-snapshot-only; sync+validation rules). The clause "`repository.id` maps to a checkout through machine-local configuration" is now satisfied by the run-from-project model (§6): the mapping is implicit in cwd + the aggregator symlink, and an identity consistency check replaces a path lookup.
- `.agents/review-exchange-v1/review-exchange.schema.json` — JSON Schema draft 2020-12, `additionalProperties:false` at envelope and every `$defs` object.
- `.agents/review-exchange-v1/workflow.md` — laptop prepares → PC verifies exact code → PC investigates → laptop inspects/publishes.
- `.agents/review-exchange-v1/naming-artifact-folders.md` — transport folder naming authority: `.local-artifacts/review` and `.artifacts--processed/review` (plural `.artifacts`, `review` not `review-exchange`).
- `.agents/review-exchange-v1/worktree-structure.md` — project worktree-root layout (arbitrary worktree names; project root holds `.local-artifacts` + worktrees).
- `.agents/review-exchange-v1/{context,result,request}.example.json` — structural exemplars.

### Pinned revisions

- Working tree is the accepted source revision. The schema version pinned by the contract is `schemaVersion: "1.0"` (`"const": "1.0"`).

### Verified facts the plan relies on

1. No existing GitLab fetch/export script exists; packaging is designed from scratch.
2. `glab` installed via `modules/home/apps/development/glab/default.nix`; instances `gitlab.com` (default) and `gitlab.rutube.ru`; token = SOPS secret `glab_DeadlySquad13_token`, exported **only** as `GITLAB_TOKEN` in `bashrcExtra` — never in the config file.
3. `gitlab.nvim` reads a per-repo `.gitlab.nvim` and does **not** model `diffRefs`; `diffRefs` exists only in the contract schema.
4. Real instance = `gitlab.rutube.ru`; no hardcoded `namespace/project` — project path is an argument.
5. OpenCode commands = markdown under `modules/home/apps/ai-assistance/opencode/commands/*.md` (frontmatter `description`, `agent`, optional `model`); `commands/test.md` is the sibling precedent for the generic harness `/review`.
6. `@salt` `aiAssistanceDir` = `/home/ds13/Projects/--personal/AiAssistance__`; `@creamsoda` Projects = `/Users/apakalo/Projects`.
7. Syncthing (current): `rut-Projects` (`/Users/apakalo/Projects` ↔ `/zsalt/shared-/@creamsoda/Projects`, bidirectional, ignore `/ai-`); `rut-Projects_artifacts` (`/Users/apakalo/Projects/.artifact` sendonly ↔ `/zsalt/shared-/@creamsoda/Projects/.artifact` receiveonly); `rut-Documents` bidirectional. `Projects/.artifact` is the **centralized raw mirror** — project-local `node_modules` and `.local-artifacts` are mirrored into it (§2/§6).
8. **New (2026-10-27):** `rut-Projects` carries `.git`, so the receiving checkout has the Git objects for the pinned OIDs; the consumer does not need a path lookup to locate the checkout (the map never guaranteed object presence anyway — it only said *where* to look).

### Assumptions

- Toolchain: **Python 3 + `invoke`** (both machines); `git` CLI (both); `glab` + `$GITLAB_TOKEN` (laptop only); `check-jsonschema` (each consumer host). No `bash`/`jq` in the runtime path.
- `glab api` returns GitLab REST field names in `snake_case`; mapping to the schema's `camelCase` is the producer's job.
- SHA-256 / ISO-8601 / UUID are produced with Python stdlib (`hashlib`, `datetime`, `uuid`) — no `shasum`/`sha256sum` branching.

---

## 2. Directory / layout proposal

Three layers, following the operator's architecture and the repo's existing patterns:

1. **Core (Python)** — raw operations, reusable on both machines:
   `shared-scripts/_features/packages/review-exchange/`
2. **Invoke wrapper** — task entry points (like `features.py`/`smug.py`):
   `shared-scripts/review_exchange.py`
3. **Thin AI-facing tools (TS)** — packaged via nix (like `pizza.ts`), used by `@salt` agents:
   `${AiAssistanceDir}/_tools/` + `modules/home/apps/ai-assistance/opencode/tools/`

```
shared-scripts/_features/packages/review-exchange/   # NEW Python core (Layer 1)
  pyproject.toml
  src/dsomega_review_exchange/
    git_ops.py          # resolve_oid, is_oid, sha256_file, diff hunk spans (git CLI)
    gitlab.py           # glab api: MR + paginated discussions/notes (snake→camel)
    capture.py          # assemble context_snapshot (no publish)
    stage.py            # assemble → verify SHA → atomic publish DIRECTLY to transport (no staging dir; name retained)
    validate.py         # schema/format/semantic/SHA/dedup/containment/identity/supersession
    materialize.py      # verify OIDs in the cwd checkout (.), produce diff
    locate.py           # find newest complete package under ./.local-artifacts/review/

shared-scripts/review_exchange.py                    # NEW invoke wrapper (Layer 2)

modules/home/apps/ai-assistance/opencode/tools/
  review-exchange.nix                                 # NEW thin TS tool wiring (Layer 3, all consumer hosts)
modules/home/apps/ai-assistance/opencode/commands/
  review.md                                           # NEW generic harness command (runs on any consumer host)

# Host/user glue (enable with the right role):
homes/aarch64-darwin/apakalo@creamsoda/...            # role = "producer" (laptop)
homes/x86_64-linux/ds13@salt/...                      # role = "consumer" (PC — one consumer host; D4: sandboxes also consume)
homes/x86_64-linux/tangerineDream@darkGreen-tangerineDream/...          # role = "consumer" (AI sandbox; shares @salt fs, D4)
homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green/...  # role = "consumer" (AI sandbox; shares @salt fs, D4)
```

**Machine-local state/config (never synced into the message):**

- `~/.config/review-exchange/review-exchange.schema.json` — installed copy of the canonical schema (**per consumer host**).
- `~/.local/state/review-exchange/imported/` — consumer dedup index (per consumer host).
- `~/.local/state/review-exchange/materialized/` — consumer materialized diff output (per consumer host, non-synced).
- `~/.local/state/review-exchange/logs/` — per-run logs (per consumer host).

> **Multi-consumer (D4):** these dirs live under the `$HOME` of each consumer host and are **not** shared between consumers. `@salt` and the AI sandboxes each have their own schema copy + state; the synced transport (`Projects/.artifact/.../review`) is read-only to all of them.

> **Dedup-index default gap (open — see §5.1.1).** `~/.local/state/review-exchange/imported/` is the intended consumer dedup index dir, but **nothing supplies it by default today**: `validate --index` has no Python default (empty → dedup/supersession are silently skipped). §5.1.1 records the candidate defaults and the recommendation, pending operator approval.

> **Removed in v2:** `~/.config/review-exchange/repo-map.json` (D3.3 — no path mapping) and `~/.local/state/review-exchange/staging/` (D3.1 — no staging hop). The remaining `review-exchange` dirs are machine-local state/config, **not** transport folders; the synced transport folder is named `review` (D3.2).

**Syncthing transport (per-top-level-folder simplex pairs — D2.1):**

Each top-level shared folder (Projects, Documents) carries its own raw→processed pair. The review-exchange reuses the **artifact-aggregator** mirror model (`move → mirror → symlink-back`), extended from `node_modules` to a project-local `.local-artifacts` dir.

| Top-level | Raw (forward, @creamsoda→@salt) | Processed (return, @salt→@creamsoda) |
|---|---|---|
| Projects | `rut-Projects_artifacts` = `Projects/.artifact` | `rut-Projects_artifacts_processed` = `Projects/.artifacts--processed` |
| Documents | `rut-Documents_artifacts` = `Documents/.artifacts` | `rut-Documents_artifacts_processed` = `Documents/.artifacts--processed` |

- **In scope:** the **Projects** pair. Review payloads live under a **`review`** subfolder (D3.2): raw = `Projects/.artifact/<project>/.local-artifacts/review/` (laptop→PC); processed = `Projects/.artifacts--processed/<project>/review/` (PC→laptop, later task).
- **Mirror model:** `Projects/.artifact` is the centralized raw mirror — each project's `node_modules` and `.local-artifacts` are mirrored into it (e.g. `Projects/.artifact/auto-hub/.local-artifacts/`), with the project-local originals symlinked back. Symlink targets are **absolute** (aggregator `.resolve()`).
- `Projects/.artifacts--processed` is the centralized processed mirror; its per-project content is copied/symlinked to project-local `Projects/<project>/.artifacts--processed` for agent consumption.
- **Plural naming:** `.artifacts` everywhere except the legacy `Projects/.artifact` (singular — too expensive to rename; Syncthing re-indexes the whole tree).
- **Ignore rules for `rut-Projects`** (bidirectional, both hosts): **`.local-artifacts`** (unanchored → project-local, any depth) and **`/.artifacts--processed`** (root-anchored). `Projects/.artifact` is auto-excluded as a nested Syncthing folder. Documents pair is out of scope.

---

## 3. Deterministic packaging (producer = laptop, runs on `@creamsoda`)

Toolchain: **Python (invoke)** + `git` CLI + `glab api`. Token read only via `$GITLAB_TOKEN` / `glab api`; **never serialized into any file, JSON field, or log** (G2).

### 3.1 `git_ops.py` — shared helpers (Layer 1)

| Function | Behavior |
|---|---|
| `sha256_file(path)` | `hashlib.sha256` → 64-hex |
| `iso_now()` | `datetime.now(timezone.utc)` → `YYYY-MM-DDTHH:MM:SSZ` |
| `new_uuid()` | `uuid.uuid4()` |
| `url_encode(s)` | `urllib.parse.quote(s, safe="")` (GitLab project-path encoding) |
| `is_oid(s)` | `^[0-9a-f]{40}([0-9a-f]{24})?$` |
| `resolve_oid(dir, rev)` | `git -C dir rev-parse rev^{commit}` → full 40/64-hex OID |

### 3.2 `capture.py` — assemble a schema-conformant `context_snapshot`

**Inputs (flags, via invoke):**

| Flag | Default | Meaning |
|---|---|---|
| `--repo-dir <path>` | `/Users/apakalo/Projects/<repo-id>` | local checkout to inspect |
| `--repo-id <id>` | basename of `--repo-dir` | → `payload.repository.id` |
| `--display-name <name>` | `<repo-id>` | → `payload.repository.displayName` |
| `--selection branch\|range` | `branch` | → `payload.comparison.selection` |
| `--head <rev>` | `git branch --show-current` | head ref/commit |
| `--target <rev>` | `main` (then `master` fallback) | target for `branch` mode |
| `--base <rev>` | (range mode only) | base commit for `range` |
| `--base-label` / `--head-label` | auto-derived | informational labels |
| `--mr <project-path>:<iid>` | (none) | capture MR + discussions via `gitlab.py` |
| `--instance <host>` | `gitlab.rutube.ru` | GitLab host for MR fetch |
| `--project-context <file>` | (repeatable) | append a `document` to `projectContext` |
| `--artifact <file>` | (repeatable) | attach supporting file → `artifacts[]` |
| `--supersedes <messageId>` | (none) | set `supersedesMessageId` |
| `--review-id <id>` | derived | override `reviewId` |
| `--dry-run` | off | compute+validate+print JSON, never publish |

**Behavior (deterministic core = pinned OIDs + captured GitLab state):**

1. Sanity: `git -C repo_dir rev-parse --git-dir` else fail.
2. Resolve OIDs:
   - `branch` mode: `baseOid = resolve_oid(merge-base(target, head))`, `headOid = resolve_oid(head)`. Default labels: `baseLabel = "merge-base(target, head)"`, `headLabel = head`.
   - `range` mode: `baseOid = resolve_oid(base)`, `headOid = resolve_oid(head)`.
3. **Changed-file inventory → `locations[]`** (deterministic given OIDs): `git diff --no-renames --unified=0 <baseOid> <headOid>`; for each changed path compute head-side (added/modified) or base-side (deleted) hunk line span:
   - modified/added → `side:"head"`, `startLine/endLine` = min/max new-file hunk start lines (1-based inclusive);
   - deleted → `side:"base"`, old-file hunk start lines;
   - binary / mode-only / rename-only with no hunk → **omit** (contract: omit unrepresentable anchors).
   - `id = "loc-<NNN>"`; `snippet` optional, omit by default. `path` = repo-relative.
4. MR capture (optional): if `--mr` given, call `gitlab.py` (§3.3). Else `discussionCapture = {"complete": true}`, `discussions = []`.
5. `projectContext`: from `--project-context` files, each → `{"format":"markdown"|"org"|"plain","text":…}`.
6. Compose `payload` with exact schema field names: `repository`, `comparison`, `capturedAt`, `mergeRequest?`, `discussionCapture`, `discussions`, `locations`, `projectContext`.
7. Identity: `reviewId = "<repo-id>-<baseOid[0:12]>..<headOid[0:12]>"` (overridable via `--review-id`); `messageId = "ctx-<reviewId>-<epochMillis>-<uuid4[0:8]>"` (fresh every capture — by design, §3.5); `supersedesMessageId` only when `--supersedes` given.
8. Envelope: `schemaVersion:"1.0"`, `createdAt = iso_now()`, `producer:"laptop"`, `kind:"context_snapshot"`, `payload`, `artifacts`.
9. `artifacts[]`: for each `--artifact`, copy to `assets/<basename>`, compute `sha256` + `sizeBytes`, `mediaType` via `mimetypes.guess_type` (fallback `application/octet-stream`); `id = "artifact-<NNN>"`.
10. Self-check: run the consumer schema-validation step (§5.1) before publishing; `--dry-run` prints JSON and exits 0 without publishing; otherwise hand off to `stage.py` (§3.4).

### 3.3 `gitlab.py` — MR + paginated discussions/notes

**Inputs:** `--instance` (default `gitlab.rutube.ru`), `--project <namespace/project>`, `--iid <n>`, `--per-page 100`.

**Behavior:**

1. Encode project path: `enc = url_encode(project)`.
2. MR: `glab api --hostname instance "projects/$enc/merge_requests/$iid"` → map (snake→camel):
   - `instanceUrl = "https://instance"`; `projectPath = project`; `iid`; `webUrl = web_url`; `title`; `description = {"format":"markdown","text":description}`; `sourceBranch = source_branch`; `targetBranch = target_branch`; `diffRefs = {"baseSha": diff_refs.base_sha, "startSha": diff_refs.start_sha, "headSha": diff_refs.head_sha}`.
   - **G1 trigger:** any required MR field (especially `diff_refs`) absent/malformed → fail; do **not** extend the schema.
3. Discussions (paginated): `glab api --hostname instance "projects/$enc/merge_requests/$iid/discussions?per_page=100&page=$page"` for `page=1,2,…` until empty/short page, with a `MAX_PAGES` guard:
   - `discussionCapture.complete = true` only if the loop ends cleanly; else `false` + `omissionReason`.
   - discussion → `{"id", "resolved" (default false), "notes":[…], "locationId"?}`; note → `{"id", "author": (username // name), "createdAt": created_at, "updatedAt": (updated_at // created_at), "body": {"format":"markdown","text": body}, "system": (system // false)}`.
   - `locationId` only when a note's `position` maps to a `locations[]` id; otherwise **omit**.
4. Return `{"mergeRequest":…, "discussionCapture":…, "discussions":[…]}` to `capture.py`.

### 3.4 `stage.py` — assemble → verify → atomic publish directly to the transport location (no staging hop)

**Inputs:** `--package-dir <dir>`, `--publish-root` (default `./.local-artifacts/review` — the project-local symlink to the centralized mirror; producer runs from the project root/worktree), `--dry-run`.

**Behavior (mirrors README sync rules 1–5; D3.1 — no separate staging dir):**

1. Assemble the package under the **final transport location** directly: `<publish-root>/<reviewId>/<messageId>/` with `message.json` + `assets/`. No `~/.local/state/review-exchange/staging/`.
2. **Write artifacts first, JSON last** (readiness signal = JSON present and self-consistent). Partial-sync is handled downstream by the consumer's SHA re-validation + retry, not by a separate staging dir.
3. Verify: re-read `message.json`, recompute each `artifacts[]` `sha256` + `sizeBytes` against the written copy; mismatch → fail (do not leave a readable `message.json`).
4. Atomic publish: `mkdir -p "<publish-root>/<reviewId>/"`; write to `.<messageId>.part/` then rename → `<publish-root>/<reviewId>/<messageId>/`. Never overwrite an existing `messageId` dir.
5. `--dry-run` prints the final layout + SHA results and exits **before** any write to the publish root.

### 3.5 Determinism — stated honestly

- **Deterministic core:** `baseOid`/`headOid`, the diff-derived `locations[]`, and captured MR/discussion fields are functions of pinned OIDs + GitLab state read at capture time.
- **Vary by design:** `capturedAt` and `messageId`. Re-capturing the same comparison yields identical `comparison`/`reviewId` but a new `messageId` (+ `supersedesMessageId` if requested). A changed comparison yields a new `reviewId`. MR discussions are a point-in-time snapshot.

---

## 4. OpenCode commands (run on any consumer host — `@salt` or a sandbox — **no GitLab credentials**)

Frontmatter follows the observed convention (`description`, `agent`, optional `model`). The body is a thin dispatcher that calls the consumer tasks (§5) and hands the materialized diff + validated context to the investigating agent. Commands never call `glab` and never read `GITLAB_TOKEN`.

### 4.1 `modules/home/apps/ai-assistance/opencode/commands/review.md` (generic harness command — D3.4)

```markdown
---
description: Open the newest (or a targeted) review package from the laptop's
  GitLab context snapshot, validate it, materialize the exact base..head code,
  and begin investigation. No GitLab credentials required.
agent: review-agent
---

# /review

Investigate a laptop-published `context_snapshot`. Thin wrapper around the
`review-exchange` consumer tasks (invoke), run from inside the project/worktree.
Everything is cwd-relative: the package lives at `./.local-artifacts/review/`
and the checkout is `.` (no host path, no repo-map). Because the command carries **no host path** and resolves everything from cwd, it is **host-agnostic**: the same command runs identically on `@salt` and each AI sandbox, each using its own `$HOME` state. This cwd-relative design is what makes multi-consumer work (D4).

Target selection (maps to `comparison.selection` + OID matching):

- `/review`                 → newest complete `context_snapshot`
                              (the laptop's default "current branch" capture).
- `/review --branch <name>` → resolve `<name>` to a full OID in the cwd
                              checkout; locate the package with
                              `selection == "branch"` and `headOid == <oid>`.
- `/review --range <base> <head>` → resolve both to full OIDs; locate the
                              package with `selection == "range"`,
                              `baseOid == <base>`, `headOid == <head>`.

Execute (in order; any failure stops):

    invoke review-exchange locate $LOCATE_ARGS            # reads ./.local-artifacts/review/
    invoke review-exchange validate --package <found message.json> \
        --schema ~/.config/review-exchange/review-exchange.schema.json \
        --repo-root .
    invoke review-exchange materialize --context <found message.json> \
        --out-dir ~/.local/state/review-exchange/materialized/

`locate` emits the newest complete package path (§5.3); its `--branch`/`--range`
resolution uses `git rev-parse <rev>^{commit}` in the cwd checkout. Matching is
by **OID**, never by label. If the requested OID has no package, report the
closest available `context_snapshot` and stop.

The dedicated review agent then reads the materialized `base..head` diff plus
the validated context and produces findings against committed code only.
```

### 4.2 Branch/range/branch-label mapping — clarification

- **"current branch"** is a *laptop-side* concept. The producer's default (`--head $(git branch --show-current)`, `--target main`) yields `selection:"branch"` with `baseOid = merge-base(target, head)`. On `@salt`, `/review` with no args takes the newest complete package.
- **"range"** = explicit `base..head` → `selection:"range"`, both OIDs pinned; `/review --range` matches both.
- **"specific branch"** = `selection:"branch"` with `headLabel` = branch name; `/review --branch <name>` matches `headOid` (and `selection:"branch"`).
- The robust join key is always the **full OID pair**; `baseLabel`/`headLabel` are informational and must never be used to resolve code.

---

## 5. "Understand the payload" tasks (run on any consumer host, from inside the project/worktree)

### 5.1 `validate.py` — structural + semantic + integrity + identity

**Inputs:** `--package <message.json>`, `--schema <path>`, `--repo-root <dir>` (default `.` — cwd), `--index <dir>` (**no Python default today** — see §5.1.1), `--allow-missing-objects`.

**Behavior (mirrors README sync rules 1–6):**

1. JSON parse; reject on parse error.
2. Reject unsupported `schemaVersion` (must be `"1.0"`).
3. **Schema validate** with `check-jsonschema` (draft 2020-12, `format` on). `additionalProperties:false` everywhere enforces unknown-field rejection.
4. **Integrity:** verify each `artifacts[]` `sha256` + `sizeBytes` against the package-relative file (resolve symlinks first).
5. **Dedup by `messageId`:** against `--index`; identical bytes → skip; same ID different bytes → conflict → fail; unknown → record.
6. **Supersession:** require same-kind/same-review parent; detect cycles, missing parents, concurrent successors → fail.
7. **Semantic references:** `contextMessageId`/`resultMessageId`/`findingIds`/`locationIds`/`artifactIds`/`discussionId`/`target.locationId` resolve; `reviewId` consistency; `1 ≤ startLine ≤ endLine`; `side`∈{base,head}.
8. **Identity consistency (replaces the path lookup — D3.3):** confirm `payload.repository.id` corresponds to the repo the consumer is currently in (cwd). Compare against the project directory name (the directory that owns the `.local-artifacts` symlink and worktrees) and/or a marker/remote in `.git/config` (e.g. a `review-exchange.repoId` key or a matching remote URL). Mismatch → fail. This is an **identity check, not a path resolution** — it never produces a checkout path.
9. **Path containment (incl. symlinks):** `location.path` stays inside `--repo-root` (cwd); `artifact.path` stays inside the package dir (no `..`/absolute/`//`/backslash; symlink + root containment).
10. **URLs:** `instanceUrl`/`webUrl` must be `https://` with no userinfo (no embedded credentials).
11. **`discussionCapture.complete == false`** ⇒ `omissionReason` must be present.
12. Exit 0 or non-zero with a machine-readable failure list.

### 5.1.1 Dedup-index default — decision-ready write-up (recommendation; operator must approve)

**Current state (incomplete).** `validate.py`'s `--index` (the consumer dedup/supersession index dir) has **no Python default** — the CLI declares `index: str = ""`, which the module maps to `index_dir = None`. With `index_dir = None`, `dedup_check` returns every message as `"new"` and `supersession_check` returns no failures: in other words, **dedup and supersession are silently skipped** (no duplicate/conflict detection, no cycle or missing-parent check) whenever `--index` is absent. The invoke wrapper (`review_exchange.py` `validate` task) mirrors this with `index: str = ""`, so `--index` is only forwarded when explicitly passed. The path is currently expected to be supplied by the caller (the nix layer), but nothing wires it yet. Contrast `materialize --out-dir`, which **does** default to `~/.local/state/review-exchange/materialized/` (in `materialize.py`). §2 already names `~/.local/state/review-exchange/imported/` as the intended index dir, so the *name* is agreed; only the *default / authority* is unresolved.

**Candidate defaults.**

| # | Option | Behavior | Pros | Cons |
|---|---|---|---|---|
| (a) | Python-level default `~/.local/state/review-exchange/imported/` | `validate.py` sets `index: str = "~/.local/state/review-exchange/imported"`; caller may still override | Portable `~`, matches `materialize --out-dir`, per-`$HOME` (correct for multi-consumer D4), single source of truth in the core | Hides the machine-local fact behind a code default; a caller can forget it is per-home |
| (b) | Keep it caller-wired (nix passes `--index ~/.local/state/review-exchange/imported/`) | Core stays `""`; the nix/invoke layer always supplies the path | Explicit wiring; core has no opinion about host filesystem | Multiple call sites must agree on the path; easy to miss a consumer; default is split across layers |
| (c) | Explicit required flag (fail if absent) | Core errors when `--index` is empty | Fail-closed: dedup/supersession can never be silently skipped | Breaks ad-hoc `validate` runs that only need structural/integrity checks; more friction for the consumer command |

**Recommendation: (a).** Make `~/.local/state/review-exchange/imported/` the Python-level default in `validate.py` (mirroring `materialize --out-dir`), keep the flag overridable, and keep the nix layer *thin* (no mandatory `--index` wiring). This is the only option that co-locates the default with the core, matches the already-accepted `materialize --out-dir` default, and is automatically correct for every consumer home (D4).

**Multi-consumer implication (D4).** The index **must** be per-`$HOME` (per consumer), never shared: `@salt`, `@darkGreen-tangerineDream`, and `@darkGreen-tangerineDream-green` each maintain their own `~/.local/state/review-exchange/imported/`. A shared index would let one consumer's import mark a message "duplicate" for all others, and its supersession chain would be polluted by cross-host state. The `~`-relative default of (a) enforces this naturally.

**Question for the operator:** Approve option (a) — add `~/.local/state/review-exchange/imported/` as the Python default for `validate --index` (overridable, per-`$HOME`, matching `materialize --out-dir`)? Or prefer (b) caller-wired / (c) required-flag?

### 5.2 `materialize.py` — verify OIDs in the cwd checkout, produce diff

**Inputs:** `--context <message.json>`, `--out-dir <dir>` (default `~/.local/state/review-exchange/materialized/`), `--fetch` (optional). No `--repo-map`; the checkout is `.` (cwd).

**Behavior:**

1. Confirm cwd is a Git worktree: `git -C . rev-parse --git-dir`; fail otherwise. (No `repository.id → checkout` resolution — the consumer runs from inside the repo, D3.3.)
2. **Verify exact code:** `git -C . cat-file -e "<baseOid>^{commit}"` and `"<headOid>^{commit}"`. On missing object → print `missing-objects: <oid>`, flag as **not materializable**, stop. Optional `--fetch` runs `git fetch origin <headOid>` (a producer-side recovery knob; expected to fail on a consumer with no fetch access — flag-and-escalate is the default, G4).
3. **Committed snapshots only:** never include working-tree edits; log a warning if `git -C . status --porcelain` shows local edits.
4. Produce the reviewable diff into `--out-dir`: `git -C . diff --no-color <baseOid> <headOid>` → `diff.patch`; `git -C . diff --stat` → `diffstat.txt`; `git -C . log --oneline <baseOid>..<headOid>` → `commits.txt`.
5. Cross-check `locations[]` line ranges against the actual blob; flag any `endLine` exceeding the blob line count.

> **Producer / consumer roles (D5).** Fetch is a **producer** capability, never a consumer one. The consumer-side `--fetch` is opt-in and defaults `False`; consumers **never** fetch — that is the point of the two-role split. The **producer** performs git-object fetch (from its local checkout / GitLab remote); in the remote/work case the producer is `@creamsoda`, and in the local case producer and consumer are both on `@salt` (or inside a sandbox sharing `@salt`'s filesystem). On a consumer, a missing OID is a hard "not materializable" flag (G4) — never a silent fetch against a remote. The shared `rut-Projects` checkout supplies the OIDs via the synced `.git`; it is **not** treated as a per-consumer object store. See RFC `docs/rfc/review-exchange-consumer-object-store.md` for the proposed improvement (per-consumer object store / producer-side `git bundle`).

### 5.3 `locate.py` — find the newest complete package

**Inputs:** `--publish-root` (default `./.local-artifacts/review` — cwd-relative; no host path, D3.4), `--kind context_snapshot`, `--review-id <id>`, `--head-oid`/`--base-oid`.

**Behavior:**

1. Resolve `--publish-root` (the `.local-artifacts` symlink may point to the centralized mirror); enumerate `<publish-root>/<reviewId>/<messageId>/message.json`, skipping `.part` temp dirs.
2. Consider "complete" only if JSON parses and all `artifacts[]` are present with matching SHA (reuse §5.1 steps 1–4).
3. Filter by `--kind` and by OID match when supplied (`payload.comparison.{baseOid,headOid}`).
4. Exclude superseded messages.
5. Sort by `createdAt` (RFC3339 lexicographic — **not** filesystem mtime) and emit the newest path.

---

## 6. Run-from-project + identity consistency (no repo-map)

The message carries only `payload.repository.id` + `displayName` — **identity only**. There is no per-host `repo-map.json` and no `repository.id → checkout` resolution (D3.3).

**Run-from-project model.** The consumer is invoked **from inside** the project/worktree. The current working directory is the single authoritative anchor for everything the consumer needs:

- **Package location:** `./.local-artifacts/review/` — the project-local symlink → the centralized mirror `Projects/.artifact/<project>/.local-artifacts/review/` (created by the artifact-aggregator `move → mirror → symlink-back`; `restore.py` recreates the symlink on the receiving host).
- **Git checkout:** `.` (cwd) — used for `cat-file -e`, `git diff base..head`, `git log`, `git show`.
- **Containment root:** `.` (cwd) — `location.path` must resolve inside it.

**Why the path map is dropped.** `.local-artifacts` is already available at the project-local path on **both** hosts via the aggregator symlink, so a separate lookup table is pure indirection. The old map also never guaranteed Git-object presence — it only said *where* to look. New fact: `rut-Projects` carries `.git`, so the OIDs are present in the synced checkout.

**Identity consistency check (in `validate.py`, §5.1 step 8).** The payload's `repository.id` is used only to confirm the consumer is in the right repo, never to locate it. `validate` compares `payload.repository.id` against:

1. the **project directory name** — the directory that owns the `.local-artifacts` symlink and the worktrees (e.g. `auto-hub`); and/or
2. a **marker/remote in `.git/config`** — e.g. a `review-exchange.repoId` git-config key, or a matching `remote.<name>.url`.

A mismatch is a validation failure (wrong-repo guard). The worktree layout that motivated the old map is unchanged, but it is now navigated by the operator choosing the cwd, not by a config file:

```text
Projects/                        # rut-Projects (bidirectional)
├── .artifact/                   # rut-Projects_artifacts — centralized raw mirror (sendonly)
│   └── auto-hub/
│       ├── .local-artifacts/    # mirrored raw artifacts (real dir)
│       │   └── review/          # ← transport: ./.local-artifacts/review/ via symlink
│       └── CurrentTask1/node_modules/   # mirrored node_modules
├── .artifacts--processed/       # rut-Projects_artifacts_processed — centralized processed (sendonly)
│   └── auto-hub/                # processed artifacts per project
└── auto-hub/                    # a project (worktree root) — consumer cwd for `git`/containment
    ├── Analytics                # worktree
    ├── CurrentTask1             # worktree (e.g. `cd` here to run /review)
    ├── Main -> …/AutoHub.git    # worktree (name arbitrary)
    ├── .local-artifacts -> …/Projects/.artifact/auto-hub/.local-artifacts   # symlink → mirror
    ├── .artifacts--processed/   # project-local processed (agent consumption)
    └── … (_configs, _http, _scripts, _utils, node_modules, shared-scripts, yarn.lock, …)
```

- The consumer runs `git -C .` from the chosen worktree (`.git` carried by `rut-Projects`), so `cat-file -e` for both OIDs works without any mapping.
- `repository.id`/`displayName` remain in the payload for stable `reviewId` construction, findings attribution, and dedup/supersession — never for path resolution (no absolute machine paths in the payload).

---

## 7. Gates — all operator decisions resolved

Standing constraints (never violated):

- **G1 — contract conformance.** If any GitLab field (notably `diff_refs.base_sha/start_sha/head_sha`) cannot map to the schema 1:1, **STOP and escalate to Architect**; do **not** extend the schema.
- **G2 — credential hygiene.** Token read only via `$GITLAB_TOKEN` / `glab api`; never serialized; no credential-bearing URLs in payload.
- **G3 — repo mapping machine-local.** `repository.id` → checkout is always local, never in the message. **In v2 this is satisfied by the run-from-project model + identity consistency check (§6), not by a `repo-map.json` config file.** The payload carries `repository.id`/`displayName` as identity only.
- **G4 — OID materialization.** `@salt` must `cat-file -e` both OIDs in the cwd checkout; missing objects are **flagged**, not silently replaced.
- **G5 — Syncthing transport/SHA/dedup/containment.** Producer: direct write to transport — artifacts then JSON → SHA verify → atomic rename (no separate staging dir, D3.1); consumer re-validates SHA, dedup by `messageId`, containment incl. symlinks, supersession-cycle detection.
- **G6 — scope boundary.** `jira`/`sentry`, and production/publication of `review_result` and `investigation_request`, are **out of scope** for this gitlab task. The return-transport **folder** `Projects/.artifacts--processed` is reserved here, but its producers/consumers are later work.

Resolved (see §0 for full detail): return-transport folder (Projects pair: `Projects/.artifact` / `Projects/.artifacts--processed`, D2.1); validator toolchain (`check-jsonschema`, D2.2); `reviewId`/`messageId` scheme (D2.3); `/review` `agent:` (dedicated review agent, D2.4); producer approach (A); MR `description`/`note.body` captured as Markdown as-is. **v2 (2026-10-27):** drop staging hop (D3.1), transport folder `review` (D3.2), drop `repo-map.json` (D3.3), `/review` as generic harness command (D3.4).

---

## 8. Ordered steps with ownership

1. **Core package (Layer 1)** `shared-scripts/_features/packages/review-exchange/` — `git_ops`, `gitlab`, `capture`, `stage` (direct-write), `validate` (identity check), `materialize` (cwd checkout), `locate` (cwd-relative). **No `repo-map.json.template`.** Verify: unit tests per module; `capture --dry-run` on a real checkout.
2. **Invoke wrapper (Layer 2)** `shared-scripts/review_exchange.py`. Verify: `invoke review-exchange --help` lists all tasks.
3. **Consumer tasks** `validate`/`materialize`/`locate`. Verify: run against `context.example.json` (structural pass) and a deliberately corrupted copy (each check must fail); confirm the identity-consistency step fails on a mismatched `repository.id`.
4. **Command** `modules/home/apps/ai-assistance/opencode/commands/review.md` (generic harness; `agent: review-agent`). Verify: `--dry-run` resolves `locate` from `./.local-artifacts/review/` and stops before mutation; grep the command for any hardcoded host path or `--repo-map` (must be absent).
5. **Thin TS tools (Layer 3)** `review-exchange.nix` + `${AiAssistanceDir}/_tools/`. Verify: `nix flake check` / narrowest home-manager eval.
6. **Host glue**: enable with `role = "producer"` on `apakalo@creamsoda`, `role = "consumer"` + the schema copy + `customTools.review-exchange` on **every consumer host** — `ds13@salt` **and** the AI sandboxes `tangerineDream@darkGreen-tangerineDream` and `tangerineDream-green@darkGreen-tangerineDream-green` (each with its own per-host schema copy and state, D4). Install the schema copy only (**no `repo-map.json`**). Verify: narrowest home-manager eval per `AGENTS.md`.
7. **Syncthing**: add the processed folder `Projects/.artifacts--processed` (receiveonly @creamsoda / sendonly @salt); add `.local-artifacts` (unanchored) and `/.artifacts--processed` (root) to `rut-Projects` `ignorePatterns` on both hosts. (Raw `rut-Projects_artifacts` = `Projects/.artifact` already exists; the Documents pair is out of scope.)
8. **End-to-end dry run**: producer snapshot (from the project root/worktree) → `validate` passes on the salt copy (identity check OK) → `materialize` reports `cat-file -e` success for both OIDs in the cwd checkout.

**Affected files/interfaces:** new `_features` package (no `repo-map.json.template`), `review_exchange.py`, `review-exchange.nix`, **`modules/home/apps/ai-assistance/opencode/commands/review.md`** (generic harness command, not `.opencode/command/review.md`), a dedicated review-agent definition, producer glue + per-consumer glue edits (schema copy + `customTools.review-exchange` on `ds13@salt` **and** both sandbox homes, D4), two Syncthing `default.nix` edits (processed folder + ignore rule). No changes to `glab`, `gitlab.nvim`, or the schema. **No data migration.** **Rollback:** delete the module enable flags + command + agent; tasks are additive and leave state only under `~/.local/state/review-exchange/` and the `Projects/.artifact` / `Projects/.artifacts--processed` transport dirs (transport subfolder `review`).

---

## 9. Validation / acceptance criteria

| Item | Criterion |
|---|---|
| Schema conformance | `validate` returns 0 on `context.example.json` (structural); rejects unknown field / wrong `schemaVersion`/`oid`/`date-time`/`uri`/`path`. |
| Determinism | two `capture --dry-run` runs on unchanged OIDs produce identical `comparison`, `locations`, `reviewId` (only `capturedAt`/`messageId` differ). |
| Code availability | `materialize` `git -C . cat-file -e` succeeds on both OIDs in the cwd checkout; missing OID → `missing-objects` flag + non-zero exit (no silent fallback). |
| Identity consistency | `validate` fails when `payload.repository.id` does not match the current repo (project dir name / `.git/config` marker); a correct match passes. No path resolution occurs. |
| Run-from-project | `locate` finds `./.local-artifacts/review/` with no `--repo-map` and no hardcoded host path (`/zsalt/…`); the consumer runs entirely from cwd. |
| Multi-consumer | the same synced package is consumable independently by `@salt` and each sandbox; each consumer keeps its own per-host `~/.local/state/review-exchange/` dedup index + materialized output (no cross-host sharing, D4). |
| Transport folder | all synced transport paths use `review` (`.local-artifacts/review/`, `.artifacts--processed/review/`); `review-exchange` appears only as contract-dir/package/tool/state naming, never as a synced folder. |
| No staging hop | the producer writes directly to the transport location; no `~/.local/state/review-exchange/staging/` exists or is referenced. |
| Integrity | every `artifacts[]` SHA-256 + `sizeBytes` recomputed and matching; tampered artifact fails. |
| Dedup/supersession | duplicate `messageId` (different bytes) → conflict; supersession cycle/missing parent → fail. |
| Containment | a `location.path` escaping the cwd root, or an `artifact.path` escaping its package dir (incl. via symlink), is rejected. |
| Credentials | grep of a produced snapshot + logs shows no `glpat-`, no `GITLAB_TOKEN` value, no `@`-credential URLs. |
| Dry-run | `--dry-run` performs full compute + validation but writes nothing to any Syncthing transport root. |
| Scope | `jira`/`sentry` fields and `review_result`/`investigation_request` producers are absent (G6). |
| No shell | runtime path contains no `bash`/`jq`/`shasum` dependencies; git plumbing via `git` CLI, GitLab via `glab api`, JSON via Python stdlib. |
