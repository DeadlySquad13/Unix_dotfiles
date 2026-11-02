> **SUPERSEDED** by [`gitlab-implementation-plan-v2.md`](./gitlab-implementation-plan-v2.md) — operator decisions 2026-10-27 (D3.1–D3.4): drop the staging hop; transport folder `review` (not `review-exchange`); drop the `repo-map.json` path mapping; `/review` as a generic harness command. Retained for history — **implement from v2, not from this file.**

# GitLab scope — laptop↔PC review exchange: implementation plan

- **Source contract:** `.agents/review-exchange-v1/README.md` (+ `review-exchange.schema.json`, `workflow.md`)
- **Route:** Explorer → Planner (plan-only; no Builder/Verifier/Reporter). Strategist not needed (intent clear). Architect not needed (contract accepted as-is; G1 escalates on any field mismatch).
- **Status:** planning complete — operator decisions resolved 2026-10-23; no implementation started. G-PLAN gate closed (see §0 and §7).

**Scope:** the **gitlab** slice only — deterministic production of a `context_snapshot` on the laptop (`@creamsoda`) and consumption/validation/materialization of that package on the PC (`@salt`). `review_result`/`investigation_request` production and the return-transport consumers are **out of scope** (G6); only the return-transport **folder** is reserved here.

---

## 0. Resolved decisions (2026-10-23) — authoritative

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

---

## 1. Inputs, pinned revisions, and assumptions

### Authoritative inputs (read, not re-derived)

- `.agents/review-exchange-v1/README.md` — contract (JSON transport; 3 immutable kinds; fresh `messageId`/`supersedesMessageId`; no credentials/paths/URLs/commands in payload; full OIDs; `repository.id` → machine-local mapping; committed-snapshot-only; sync+validation rules).
- `.agents/review-exchange-v1/review-exchange.schema.json` — JSON Schema draft 2020-12, `additionalProperties:false` at envelope and every `$defs` object.
- `.agents/review-exchange-v1/workflow.md` — laptop prepares → PC verifies exact code → PC investigates → laptop inspects/publishes.
- `.agents/review-exchange-v1/{context,result,request}.example.json` — structural exemplars.

### Pinned revisions

- Working tree is the accepted source revision. The schema version pinned by the contract is `schemaVersion: "1.0"` (`"const": "1.0"`).

### Verified facts the plan relies on

1. No existing GitLab fetch/export script exists; packaging is designed from scratch.
2. `glab` installed via `modules/home/apps/development/glab/default.nix`; instances `gitlab.com` (default) and `gitlab.rutube.ru`; token = SOPS secret `glab_DeadlySquad13_token`, exported **only** as `GITLAB_TOKEN` in `bashrcExtra` — never in the config file.
3. `gitlab.nvim` reads a per-repo `.gitlab.nvim` and does **not** model `diffRefs`; `diffRefs` exists only in the contract schema.
4. Real instance = `gitlab.rutube.ru`; no hardcoded `namespace/project` — project path is an argument.
5. OpenCode commands = markdown in project `.opencode/command/*.md`, frontmatter `description`, `agent`, optional `model`.
6. `@salt` `aiAssistanceDir` = `/home/ds13/Projects/--personal/AiAssistance__`; `@creamsoda` Projects = `/Users/apakalo/Projects`.
7. Syncthing (current): `rut-Projects` (`/Users/apakalo/Projects` ↔ `/zsalt/shared-/@creamsoda/Projects`, bidirectional, ignore `/ai-`); `rut-Projects_artifacts` (`/Users/apakalo/Projects/.artifact` sendonly ↔ `/zsalt/shared-/@creamsoda/Projects/.artifact` receiveonly); `rut-Documents` bidirectional. `Projects/.artifact` is the **centralized raw mirror** — project-local `node_modules` and `.local-artifacts` are mirrored into it (§2/§6).

### Assumptions

- Toolchain: **Python 3 + `invoke`** (both machines); `git` CLI (both); `glab` + `$GITLAB_TOKEN` (laptop only); `check-jsonschema` (PC). No `bash`/`jq` in the runtime path.
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
    stage.py            # staging → verify SHA → atomic publish
    validate.py         # schema/format/semantic/SHA/dedup/containment/supersession
    materialize.py      # repo-id→checkout, cat-file -e, produce diff
    locate.py           # find newest complete package
  templates/repo-map.json.template

shared-scripts/review_exchange.py                    # NEW invoke wrapper (Layer 2)

modules/home/apps/ai-assistance/opencode/tools/
  review-exchange.nix                                 # NEW thin TS tool wiring (Layer 3, @salt)
.opencode/command/review.md                           # NEW project command (runs on @salt)

# Host/user glue (enable with the right role):
homes/aarch64-darwin/apakalo@creamsoda/...            # role = "producer" (laptop)
homes/x86_64-linux/ds13@salt/...                      # role = "consumer" (PC)
```

**Machine-local state/config (never synced into the message):**

- `~/.config/review-exchange/repo-map.json` — `repository.id` → checkout mapping (per machine).
- `~/.config/review-exchange/review-exchange.schema.json` — installed copy of the canonical schema.
- `~/.local/state/review-exchange/staging/` — laptop private staging (never a Syncthing folder).
- `~/.local/state/review-exchange/imported/` — consumer dedup index (PC-local).
- `~/.local/state/review-exchange/materialized/` — consumer materialized diff output (PC-local, non-synced).
- `~/.local/state/review-exchange/logs/` — per-run logs.

**Syncthing transport (per-top-level-folder simplex pairs — D2.1):**

Each top-level shared folder (Projects, Documents) carries its own raw→processed pair. The review-exchange reuses the **artifact-aggregator** mirror model (`move → mirror → symlink-back`), extended from `node_modules` to a project-local `.local-artifacts` dir.

| Top-level | Raw (forward, @creamsoda→@salt) | Processed (return, @salt→@creamsoda) |
|---|---|---|
| Projects | `rut-Projects_artifacts` = `Projects/.artifact` | `rut-Projects_artifacts_processed` = `Projects/.artifacts--processed` |
| Documents | `rut-Documents_artifacts` = `Documents/.artifacts` | `rut-Documents_artifacts_processed` = `Documents/.artifacts--processed` |

- **In scope:** the **Projects** pair. Review payloads live under a `review` subfolder: raw = `Projects/.artifact/<project>/.local-artifacts/review/` (laptop→PC); processed = `Projects/.artifacts--processed/<project>/review/` (PC→laptop, later task).
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

### 3.4 `stage.py` — staging → verify → atomic publish

**Inputs:** `--package-dir <dir>`, `--staging-root` (default `~/.local/state/review-exchange/staging`), `--publish-root` (default `/Users/apakalo/Projects/.artifact/<project>/.local-artifacts/review`), `--dry-run`.

**Behavior (mirrors README sync rules 1–5):**

1. Assemble in **private staging** (not a Syncthing folder): `<staging>/<reviewId>/<messageId>/` with `message.json` + `assets/`.
2. **Write artifacts first, JSON last** (readiness signal = JSON present and self-consistent).
3. Verify: re-read `message.json`, recompute each `artifacts[]` `sha256` + `sizeBytes` against the staged copy; mismatch → fail.
4. Atomic publish: `mkdir -p "<publish>/<reviewId>/"`; write to `.<messageId>.part/` then rename → `<publish>/<reviewId>/<messageId>/`. Never overwrite an existing `messageId` dir.
5. `--dry-run` prints the final layout + SHA results and exits **before** any write to the publish root.

### 3.5 Determinism — stated honestly

- **Deterministic core:** `baseOid`/`headOid`, the diff-derived `locations[]`, and captured MR/discussion fields are functions of pinned OIDs + GitLab state read at capture time.
- **Vary by design:** `capturedAt` and `messageId`. Re-capturing the same comparison yields identical `comparison`/`reviewId` but a new `messageId` (+ `supersedesMessageId` if requested). A changed comparison yields a new `reviewId`. MR discussions are a point-in-time snapshot.

---

## 4. OpenCode commands (run on `@salt`, **no GitLab credentials**)

Frontmatter follows the observed convention (`description`, `agent`, optional `model`). The body is a thin dispatcher that calls the consumer tasks (§5) and hands the materialized diff + validated context to the investigating agent. Commands never call `glab` and never read `GITLAB_TOKEN`.

### 4.1 `.opencode/command/review.md`

```markdown
---
description: Open the newest (or a targeted) review package from the laptop's
  GitLab context snapshot, validate it, materialize the exact base..head code,
  and begin investigation. No GitLab credentials required.
agent: review-agent
---

# /review

Investigate a laptop-published `context_snapshot`. Thin wrapper around the
`review-exchange` consumer tasks (invoke).

Target selection (maps to `comparison.selection` + OID matching):

- `/review`                 → newest complete `context_snapshot`
                              (the laptop's default "current branch" capture).
- `/review --branch <name>` → resolve `<name>` to a full OID in the mapped
                              checkout; locate the package with
                              `selection == "branch"` and `headOid == <oid>`.
- `/review --range <base> <head>` → resolve both to full OIDs; locate the
                              package with `selection == "range"`,
                              `baseOid == <base>`, `headOid == <head>`.

Execute (in order; any failure stops):

    invoke review-exchange locate --publish-root /zsalt/shared-/@creamsoda/Projects/.artifact/<project>/.local-artifacts/review $LOCATE_ARGS
    invoke review-exchange validate --package <found message.json> \
        --schema ~/.config/review-exchange/review-exchange.schema.json \
        --repo-map ~/.config/review-exchange/repo-map.json
    invoke review-exchange materialize --context <found message.json> \
        --repo-map ~/.config/review-exchange/repo-map.json \
        --out-dir ~/.local/state/review-exchange/materialized/

`locate` emits the newest complete package path (§5.3); its `--branch`/`--range`
resolution uses `git rev-parse <rev>^{commit}` in the checkout mapped from
`payload.repository.id` (§6). Matching is by **OID**, never by label. If the
requested OID has no package, report the closest available `context_snapshot`
and stop.

The dedicated review agent then reads the materialized `base..head` diff plus
the validated context and produces findings against committed code only.
```

### 4.2 Branch/range/branch-label mapping — clarification

- **"current branch"** is a *laptop-side* concept. The producer's default (`--head $(git branch --show-current)`, `--target main`) yields `selection:"branch"` with `baseOid = merge-base(target, head)`. On `@salt`, `/review` with no args takes the newest complete package.
- **"range"** = explicit `base..head` → `selection:"range"`, both OIDs pinned; `/review --range` matches both.
- **"specific branch"** = `selection:"branch"` with `headLabel` = branch name; `/review --branch <name>` matches `headOid` (and `selection:"branch"`).
- The robust join key is always the **full OID pair**; `baseLabel`/`headLabel` are informational and must never be used to resolve code.

---

## 5. "Understand the payload" tasks (run on `@salt`)

### 5.1 `validate.py` — structural + semantic + integrity

**Inputs:** `--package <message.json>`, `--schema <path>`, `--repo-map <path>`, `--index <dir>` (default `~/.local/state/review-exchange/imported/`), `--allow-missing-objects`.

**Behavior (mirrors README sync rules 1–6):**

1. JSON parse; reject on parse error.
2. Reject unsupported `schemaVersion` (must be `"1.0"`).
3. **Schema validate** with `check-jsonschema` (draft 2020-12, `format` on). `additionalProperties:false` everywhere enforces unknown-field rejection.
4. **Integrity:** verify each `artifacts[]` `sha256` + `sizeBytes` against the package-relative file (resolve symlinks first).
5. **Dedup by `messageId`:** against `--index`; identical bytes → skip; same ID different bytes → conflict → fail; unknown → record.
6. **Supersession:** require same-kind/same-review parent; detect cycles, missing parents, concurrent successors → fail.
7. **Semantic references:** `contextMessageId`/`resultMessageId`/`findingIds`/`locationIds`/`artifactIds`/`discussionId`/`target.locationId` resolve; `reviewId` consistency; `1 ≤ startLine ≤ endLine`; `side`∈{base,head}.
8. **Path containment (incl. symlinks):** `location.path` stays inside the mapped checkout; `artifact.path` stays inside the package dir (no `..`/absolute/`//`/backslash; symlink + root containment).
9. **URLs:** `instanceUrl`/`webUrl` must be `https://` with no userinfo (no embedded credentials).
10. **`discussionCapture.complete == false`** ⇒ `omissionReason` must be present.
11. Exit 0 or non-zero with a machine-readable failure list.

### 5.2 `materialize.py` — repo-id → checkout, verify OIDs, produce diff

**Inputs:** `--context <message.json>`, `--repo-map <path>`, `--out-dir <dir>` (default `~/.local/state/review-exchange/materialized/`), `--fetch` (optional).

**Behavior:**

1. Resolve `payload.repository.id` → checkout via `repo-map.json` (§6). Fail on unknown id.
2. **Verify exact code:** `git -C checkout cat-file -e "<baseOid>^{commit}"` and `"<headOid>^{commit}"`. On missing object → print `missing-objects: <oid>`, flag as **not materializable**, stop. Optional `--fetch` runs `git fetch origin <headOid>` (expected to fail on `@salt`; flag-and-escalate is the default, G4).
3. **Committed snapshots only:** never include working-tree edits; log a warning if `git status --porcelain` shows local edits.
4. Produce the reviewable diff into `--out-dir`: `git diff --no-color <baseOid> <headOid>` → `diff.patch`; `git diff --stat` → `diffstat.txt`; `git log --oneline <baseOid>..<headOid>` → `commits.txt`.
5. Cross-check `locations[]` line ranges against the actual blob; flag any `endLine` exceeding the blob line count.

### 5.3 `locate.py` — find the newest complete package

**Inputs:** `--publish-root` (default `/zsalt/shared-/@creamsoda/Projects/.artifact/<project>/.local-artifacts/review`), `--kind context_snapshot`, `--review-id <id>`, `--head-oid`/`--base-oid`.

**Behavior:**

1. Enumerate `<publish-root>/<reviewId>/<messageId>/message.json`, skipping `.part` temp dirs.
2. Consider "complete" only if JSON parses and all `artifacts[]` are present with matching SHA (reuse §5.1 steps 1–4).
3. Filter by `--kind` and by OID match when supplied (`payload.comparison.{baseOid,headOid}`).
4. Exclude superseded messages.
5. Sort by `createdAt` (RFC3339 lexicographic — **not** filesystem mtime) and emit the newest path.

---

## 6. Repository-id → checkout mapping (machine-local, never in the message)

The message carries only `payload.repository.id` + `displayName`. Each machine resolves the id locally.

**Project worktree-root model.** A project root holds multiple git **worktrees** plus auxiliary (non-worktree) dirs/files. Worktree names are **arbitrary** (`Main`, `Master`, `Analytics`, `CurrentTask1`, `Release`, `Review`, …) and never fixed — `repository.id` must resolve to a specific checkout via the map, never by guessing a worktree name. The auxiliary dirs hold `.local-artifacts` (project-local raw artifacts), which are **mirrored** into the centralized `Projects/.artifact/<project>/.local-artifacts` (with a symlink left at the project-local spot) — the same mechanism the aggregator already uses for `node_modules`.

```text
Projects/                        # rut-Projects (bidirectional)
├── .artifact/                   # rut-Projects_artifacts — centralized raw mirror (sendonly)
│   └── auto-hub/
│       ├── .local-artifacts/    # mirrored raw artifacts (real dir)
│       └── CurrentTask1/node_modules/   # mirrored node_modules
├── .artifacts--processed/       # rut-Projects_artifacts_processed — centralized processed (sendonly)
│   └── auto-hub/                # processed artifacts per project
└── auto-hub/                    # a project (worktree root)
    ├── Analytics                # worktree
    ├── CurrentTask1             # worktree
    ├── Main -> …/AutoHub.git    # worktree (name arbitrary)
    ├── .local-artifacts -> …/Projects/.artifact/auto-hub/.local-artifacts   # symlink → mirror
    ├── .artifacts--processed/   # project-local processed (agent consumption)
    └── … (_configs, _http, _scripts, _utils, node_modules, shared-scripts, yarn.lock, …)
```

**Config file (per machine):** `~/.config/review-exchange/repo-map.json`

```json
{
  "baseDir": "/zsalt/shared-/@creamsoda/Projects",
  "repositories": {
    "auto-hub": "auto-hub/CurrentTask1"
  }
}
```

- `baseDir` per machine: `@salt` → `/zsalt/shared-/@creamsoda/Projects`; `@creamsoda` → `/Users/apakalo/Projects` (the two ends of `rut-Projects`).
- `repositories` maps `repository.id` → a **worktree path** relative to `baseDir` (project + worktree). Worktree names are explicit in the map, never inferred.
- Resolution result is absolute and used by `materialize.py`; the mapping **never** appears in `context_snapshot` (no absolute machine paths in payload).

---

## 7. Gates — all operator decisions resolved

Standing constraints (never violated):

- **G1 — contract conformance.** If any GitLab field (notably `diff_refs.base_sha/start_sha/head_sha`) cannot map to the schema 1:1, **STOP and escalate to Architect**; do **not** extend the schema.
- **G2 — credential hygiene.** Token read only via `$GITLAB_TOKEN` / `glab api`; never serialized; no credential-bearing URLs in payload.
- **G3 — repo mapping machine-local.** `repository.id` → checkout is always local config, never in the message.
- **G4 — OID materialization.** `@salt` must `cat-file -e` both OIDs; missing objects are **flagged**, not silently replaced.
- **G5 — Syncthing staging/SHA/dedup/containment.** Producer: private staging → artifacts then JSON → SHA verify → atomic rename; consumer re-validates SHA, dedup by `messageId`, containment incl. symlinks, supersession-cycle detection.
- **G6 — scope boundary.** `jira`/`sentry`, and production/publication of `review_result` and `investigation_request`, are **out of scope** for this gitlab task. The return-transport **folder** `Projects/.artifacts--processed` is reserved here, but its producers/consumers are later work.

Resolved (see §0 for full detail): return-transport folder (Projects pair: `Projects/.artifact` / `Projects/.artifacts--processed`, D2.1); validator toolchain (`check-jsonschema`, D2.2); `reviewId`/`messageId` scheme (D2.3); `/review` `agent:` (dedicated review agent, D2.4); producer approach (A); MR `description`/`note.body` captured as Markdown as-is.

---

## 8. Ordered steps with ownership

1. **Core package (Layer 1)** `shared-scripts/_features/packages/review-exchange/` — `git_ops`, `gitlab`, `capture`, `stage`, `validate`, `materialize`, `locate` + `repo-map.json.template`. Verify: unit tests per module; `capture --dry-run` on a real checkout.
2. **Invoke wrapper (Layer 2)** `shared-scripts/review_exchange.py`. Verify: `invoke review-exchange --help` lists all tasks.
3. **Consumer tasks** `validate`/`materialize`/`locate`. Verify: run against `context.example.json` (structural pass) and a deliberately corrupted copy (each check must fail).
4. **Command** `.opencode/command/review.md` (dedicated `review-agent`). Verify: `--dry-run` resolves `locate` and stops before mutation.
5. **Thin TS tools (Layer 3)** `review-exchange.nix` + `${AiAssistanceDir}/_tools/`. Verify: `nix flake check` / narrowest home-manager eval.
6. **Host glue**: enable with `role = "producer"` on `apakalo@creamsoda`, `role = "consumer"` on `ds13@salt`; install `repo-map.json` defaults + schema copy. Verify: narrowest home-manager eval per `AGENTS.md`.
7. **Syncthing**: add the processed folder `Projects/.artifacts--processed` (receiveonly @creamsoda / sendonly @salt); add `.local-artifacts` (unanchored) and `/.artifacts--processed` (root) to `rut-Projects` `ignorePatterns` on both hosts. (Raw `rut-Projects_artifacts` = `Projects/.artifact` already exists; the Documents pair is out of scope.)
8. **End-to-end dry run**: producer snapshot → `validate` passes on the salt copy → `materialize` reports `cat-file -e` success for both OIDs.

**Affected files/interfaces:** new `_features` package, `review_exchange.py`, `review-exchange.nix`, `.opencode/command/review.md`, a dedicated review-agent definition, two `homes/...` glue edits, two Syncthing `default.nix` edits (processed folder + ignore rule). No changes to `glab`, `gitlab.nvim`, or the schema. **No data migration.** **Rollback:** delete the module enable flags + command + agent; tasks are additive and leave state only under `~/.local/state/review-exchange/` and the `Projects/.artifact` / `Projects/.artifacts--processed` transport dirs.

---

## 9. Validation / acceptance criteria

| Item | Criterion |
|---|---|
| Schema conformance | `validate` returns 0 on `context.example.json` (structural); rejects unknown field / wrong `schemaVersion`/`oid`/`date-time`/`uri`/`path`. |
| Determinism | two `capture --dry-run` runs on unchanged OIDs produce identical `comparison`, `locations`, `reviewId` (only `capturedAt`/`messageId` differ). |
| Code availability | `materialize` `git cat-file -e` succeeds on both OIDs; missing OID → `missing-objects` flag + non-zero exit (no silent fallback). |
| Integrity | every `artifacts[]` SHA-256 + `sizeBytes` recomputed and matching; tampered artifact fails. |
| Dedup/supersession | duplicate `messageId` (different bytes) → conflict; supersession cycle/missing parent → fail. |
| Containment | a `location.path` or `artifact.path` escaping its root (incl. via symlink) is rejected. |
| Credentials | grep of a produced snapshot + logs shows no `glpat-`, no `GITLAB_TOKEN` value, no `@`-credential URLs. |
| Dry-run | `--dry-run` performs full compute + validation but writes nothing to any Syncthing transport root. |
| Scope | `jira`/`sentry` fields and `review_result`/`investigation_request` producers are absent (G6). |
| No shell | runtime path contains no `bash`/`jq`/`shasum` dependencies; git plumbing via `git` CLI, GitLab via `glab api`, JSON via Python stdlib. |
