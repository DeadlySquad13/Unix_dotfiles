# GitLab scope — laptop↔PC review exchange: implementation plan (v3)

> **Supersession history.** This document **supersedes** [`gitlab-implementation-plan-v2.md`](./gitlab-implementation-plan-v2.md) (2026-10-27 revision). It records three further operator decisions made **2026-10-27** (D6.1–D6.2 concurrency fixes, D7 state-directory relocation, §0) and rewrites the affected sections (§2, §4.1, §5.1, §5.1.1, §5.2, §7, §8, §9) plus a new §10 (diagrams). The v2 document is retained for history and points back here; **implement from this v3.**

- **Source contract:** `.agents/review-exchange-v1/README.md` (+ `review-exchange.schema.json`, `workflow.md`, `naming-artifact-folders.md`)
- **Route:** v1 = Explorer → Planner (plan-only). v2 = **Architect** superseding plan (no code). v3 = **Architect** superseding plan (no code). The new decisions (D6.1–D6.2, D7) are operator-confirmed *mechanism* changes, not user-intent changes, so Strategist is not needed. G1 still escalates on any contract-field mismatch.
- **Status:** v3 supersedes v2 (operator decisions resolved 2026-10-27). Implementation files (`shared-scripts`, Python `_features`, Nix tooling) are being edited **in parallel by other agents and are out of scope for this document**. G-PLAN gate closed (see §0 and §7).

**Scope:** the **gitlab** slice only — deterministic production of a `context_snapshot` on the laptop (`@creamsoda`) and consumption/validation/materialization of that package on the PC (`@salt` and the AI sandboxes). `review_result`/`investigation_request` production and the return-transport consumers are **out of scope** (G6); only the return-transport **folder** is reserved here.

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
| Consumer | `--out-dir` default | **Changed in v3 (D6.1/D7):** per-review `materialized/<messageId>/` under the host state root; see D6.1/D7. |
| **D3.1** | **Drop the staging hop** | **Remove `~/.local/state/review-exchange/staging/`.** The producer writes directly into the final transport location, preserving "artifacts first, `message.json` last" (JSON presence = readiness) plus the consumer's SHA re-validation + retry. Rationale: the consumer (`locate`/`validate`) already treats a package as complete only when `message.json` parses AND every artifact SHA-256/sizeBytes matches, so partial-sync is already handled; a separate non-synced staging dir is redundant belt-and-suspenders. |
| **D3.2** | **Transport folder name** | **`review`, not `review-exchange`** — `naming-artifact-folders.md` already settled this: `.local-artifacts/review/` (raw) and `.artifacts--processed/review/` (processed). The string `review-exchange` is retained **only** for the contract dir (`.agents/review-exchange-v1/`), the Python package, the invoke task name, the TS tool (`review-exchange.nix`), and machine-local state/config — **never** as a synced transport folder. |
| **D3.3** | **Drop `repo-map.json` path mapping** | **Remove** the per-host `repository.id → checkout` config entirely. The consumer runs **from inside** the project/worktree and uses relative paths: package at `./.local-artifacts/review/` (project-local symlink → the centralized mirror, created by the artifact-aggregator `move → mirror → symlink-back` and recreated by `restore.py` on the receiving host); git checkout `.` (cwd); containment root `.` (cwd). Rationale: `.local-artifacts` is already project-local on both hosts via the aggregator symlink, so a path lookup is pure indirection. **New fact:** `rut-Projects` carries `.git`, so the OIDs are present in the synced checkout. `repository.id` + `displayName` stay in the payload but **only as identity** (stable `reviewId`, findings attribution, dedup/supersession), never for path resolution. `validate` performs an **identity consistency check** instead of a path lookup. |
| **D3.4** | **`/review` command location** | **Generic harness command** at `modules/home/apps/ai-assistance/opencode/commands/review.md` (sibling of `commands/test.md`), **not** project-local `.opencode/command/review.md`. It carries **no hardcoded host path** (no `/zsalt/...`), **no `--repo-map`**, and reads `./.local-artifacts/review/` relative to cwd. |
| **D4** | **Consumer = a set of filesystem-sharing hosts, not a single host** | **Transport (Syncthing) is unchanged**: `@creamsoda` ↔ `@salt` only; the sandboxes do **not** run Syncthing. **Consumption generalizes**: any host that can reach the synced `Projects` tree is consumer-capable — in practice `@salt` **plus** the AI sandboxes `@darkGreen-tangerineDream` and `@darkGreen-tangerineDream-green` (and their `_inner` counterparts), where the OpenCode review agents actually run. **Per-host consumer state**: each consumer host has its own state root (see D7) and schema copy; the synced transport is read-only to consumers. |
| **D5** | **Producer / consumer roles (host-independent)** | **Every review-exchange run has exactly two roles, and neither is bound to a specific host.** The **producer** has git-fetch access; the **consumer** has no fetch access and relies on the synced checkout for the OIDs `cat-file -e` needs. Scenarios: **(1) remote/work** — producer `@creamsoda`, consumer `@salt` or a sandbox; **(2) local** — producer and consumer are agents on the **same** `@salt` (or inside a sandbox sharing `@salt`'s filesystem). `materialize --fetch` is a **producer-side recovery knob, never a consumer capability**. The shared checkout is **not** a per-consumer object store (§5.2). |
| **D6.1** | **`materialize` output is per-review** | **`materialize` writes into `materialized/<messageId>/`**, not a single fixed dir. Default out root is the host state root (D7): `<state-root>/review/materialized/<messageId>/`. Rationale: multiple agents on ONE home review different projects/diffs concurrently; a fixed dir would make concurrent `materialize` runs overwrite each other's `diff.patch`/`diffstat.txt`/`commits.txt`. |
| **D6.2** | **Dedup/supersession index writes are atomic** | **Index writes (`imported/<messageId>.json`) must be atomic — write to a temp file in the same dir, then `os.replace()`/rename into place.** Rationale: `supersession_check` and `locate` `glob` the index dir; a non-atomic write can expose a half-written JSON file that a concurrent reader parses as corrupt. Temp-then-rename means readers only ever observe a complete file. |
| **D7** | **State-directory relocation (drop `~/.local/state/review-exchange`)** | **The consumer state dir becomes `<state-root>/review/`** (note: `review`, not `review-exchange` — consistent with D3.2). It is **HOST-SPECIFIC** and resolved via the environment variable **`REVIEW_EXCHANGE_STATE_DIR`** (the Python reads this env var; a portable `~/.local/state/review` is only a **fallback for manual runs**). Under `review/`: `imported/` (dedup/supersession index) and `materialized/<messageId>/` (per-review output). **The implementation must `mkdir -p` these** (they may not exist). Per-host values are recorded in §2.1. |

**Superseded/amended prior entries:** D2.1's folder *pairs* are unchanged, but the transport *subfolder* is `review` (D3.2). The machine-local-state list in §2 no longer contains `repo-map.json` (D3.3), `staging/` (D3.1), or the `~/.local/state/review-exchange` path (D7). The prior "`--out-dir` default `~/.local/state/review-exchange/materialized/`" entry is replaced by D6.1/D7 (per-review output under the host state root). The single-consumer assumption is replaced by D4; the fetch boundary by D5. **New in v3:** concurrency fixes (D6.1 per-review materialize output, D6.2 atomic index writes) and the state-dir relocation + env var (D7).

**Open questions / follow-ups (recorded, not yet decided):**

- **O1 — schema-copy rename (operator question) — RESOLVED (2026-10-27).** The installed schema copy stays at `~/.config/review-exchange/review-exchange.schema.json` (config, not state). **Operator decision: keep `~/.config/review-exchange/` — no rename.** D7 relocates state only, not config; the `review-exchange` string remains valid here as machine-local config/package/tool naming (D3.2).
- **O2 — `/review` `--out-dir` drop (nix/config-agent follow-up).** The `/review` command currently hardcodes `--out-dir ~/.local/state/review-exchange/materialized/` (v2 §4.1). It **must be updated to drop `--out-dir`** and let `materialize` derive the per-review dir from `REVIEW_EXCHANGE_STATE_DIR` (D6.1/D7). Flagged as a **follow-up for the nix/config agent** (the command markdown is out of scope for this document). The nix layer must also set `REVIEW_EXCHANGE_STATE_DIR` per host (salt vs sandbox).

---

## 1. Inputs, pinned revisions, and assumptions

### Authoritative inputs (read, not re-derived)

- `.agents/review-exchange-v1/README.md` — contract (JSON transport; 3 immutable kinds; fresh `messageId`/`supersedesMessageId`; no credentials/paths/URLs/commands in payload; full OIDs; committed-snapshot-only; sync+validation rules). The clause "`repository.id` maps to a checkout through machine-local configuration" is now satisfied by the run-from-project model (§6).
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
7. Syncthing (current): `rut-Projects` (`/Users/apakalo/Projects` ↔ `/zsalt/shared-/@creamsoda/Projects`, bidirectional, ignore `/ai-`); `rut-Projects_artifacts` (`/Users/apakalo/Projects/.artifact` sendonly ↔ `/zsalt/shared-/@creamsoda/Projects/.artifact` receiveonly); `rut-Documents` bidirectional. `Projects/.artifact` is the **centralized raw mirror**.
8. **New (2026-10-27):** `rut-Projects` carries `.git`, so the receiving checkout has the Git objects for the pinned OIDs.
9. **New (2026-10-27):** the sandboxes mount per-host state through shared volumes declared in `docker-compose.darkGreen-tangerineDream-base.yml` (in the `@tangerineDream` repo), giving the sandbox view `/usr/local/${SPICE_NAMESPACE}-/${SYSTEM_BASE_NAME}/_state/…` (see §2.1).

10. **New (2026-10-27):** sandbox namespace roots are pinned in `lib/runtime-home-bridge/default.nix` `catalogs.*`: `darkGreen-tangerineDream` → `namespaceRoot = /usr/local/darkGreen-/tangerineDream`, `zNamespaceRoot = /ztangerineDream`; `darkGreen-tangerineDream-green` → `namespaceRoot = /usr/local/darkGreen-/tangerineDream-green`, `zNamespaceRoot = /ztangerineDream-green`. Resolution rule (`resolveMapping`): `source` → `${namespaceRoot}/${source}` (sandbox view); `zSource` → `${zNamespaceRoot}/${zSource}` (salt zfs view), with `zSource` preferred when both are present.
11. **New (2026-10-27):** the `_state` mount is real and lives under `namespaceRoot`: `opencodeBase` maps `_state/opencode` → `.local/state/opencode` (alongside `_cache`→`.cache`, `_share`→`.local/share`), so `_state/review` is the review state dir at `/usr/local/darkGreen-/<base>/_state/review` — matching the D7 per-host values (the `_state/…` links resolve via the `source` branch, i.e. the sandbox view).
12. **New (2026-10-27):** the bridge maps the sandbox's `projects` to **`@salt`'s own projects**, not `@creamsoda`'s synced tree: `darkGreen-tangerineDream` `baseForSwitch` = `{ zSource = "shared-/@salt/Projects"; source = "Projects"; target = ".bookmarks/projects"; }` (**switch-time only**); `darkGreen-tangerineDream-green` maps **only** `Projects/--personal/AiAssistance__` (target `.bookmarks/projects/--personal/AiAssistance__`), no full `Projects`.
13. **New (2026-10-27):** the Syncthing transport (`homes/x86_64-linux/ds13@salt/syncthing/default.nix`) is `@creamsoda`'s tree: `rut-Projects` → `/zsalt/shared-/@creamsoda/Projects` (bidirectional), `rut-Projects_artifacts` → `/zsalt/shared-/@creamsoda/Projects/.artifact` (**receiveonly**). This `@creamsoda` path is **absent from the bridge catalogs** — the runtime-home-bridge does **not** expose `@creamsoda`'s synced `Projects` to the sandboxes (see §2.1 "Transport-mount distinction").

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
    materialize.py      # verify OIDs in the cwd checkout (.), produce diff (per-review output)
    locate.py           # find newest complete package under ./.local-artifacts/review/
    state.py            # NEW: read REVIEW_EXCHANGE_STATE_DIR (= <state-root>/review, the review dir) (D7)

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

- `~/.config/review-exchange/review-exchange.schema.json` — installed copy of the canonical schema (**config**, per consumer host; **unchanged by D7** — O1 resolved: keep this path, no rename).
- `<state-root>/review/imported/` — consumer dedup/supersession index (per consumer host; D7).
- `<state-root>/review/materialized/<messageId>/` — consumer materialized diff output (per consumer host, per-review; D6.1/D7).
- `<state-root>/review/logs/` — per-run logs (per consumer host; D7).

> **Multi-consumer (D4) + host-specific state (D7):** state lives under the `REVIEW_EXCHANGE_STATE_DIR` of each consumer host and is **not** shared between consumers. `@salt` and the AI sandboxes each have their own state root + schema copy; the synced transport (`Projects/.artifact/.../review`) is read-only to all of them.

> **Removed in v2/v3:** `~/.config/review-exchange/repo-map.json` (D3.3), `~/.local/state/review-exchange/staging/` (D3.1), and `~/.local/state/review-exchange/` as a whole (D7 — replaced by `<state-root>/review/`). The remaining `review-exchange` string is machine-local config/package/tool naming, **not** a synced transport folder and **not** a state dir; the synced transport folder and the state dir are both named `review` (D3.2/D7).

### 2.1 Consumer state directory (D7) — authoritative

- **Env var:** `REVIEW_EXCHANGE_STATE_DIR`. This env var **is the review dir** — its value **is `<state-root>/review`** (the full path, **including the `/review` component**), **not** the bare `<state-root>`. The Python core (`state.py`) reads the env var directly as the review dir; it does **not** append `/review`. If the env var is unset, a portable fallback `~/.local/state/review` is used **only for manual runs** (never the production path) — note this fallback already matches the shape: it **is** the review dir (`<state-root>` = `~/.local/state`, plus `/review`). The nix layer must set this env var per host (salt vs sandbox).
- **Layout under `$REVIEW_EXCHANGE_STATE_DIR`** (= `<state-root>/review`, the review dir):
  - `imported/` — dedup/supersession index (`<messageId>.json` entries).
  - `materialized/<messageId>/` — per-review materialize output (`diff.patch`, `diffstat.txt`, `commits.txt`).
  - `logs/` — per-run logs.
- **These directories may not exist on first use** — the implementation must create them with `mkdir -p`.
- **Per-host values (record exactly):**

| Host | `<state-root>` (bare state root — **not** the env var) | `REVIEW_EXCHANGE_STATE_DIR` (= `<state-root>/review`, the review dir) |
|---|---|---|
| `@salt` | `/zsalt/var-/ds13@salt/state` | `/zsalt/var-/ds13@salt/state/review` |
| `@darkGreen-tangerineDream` (sandbox) | on salt: `/zsalt/var-/tangerineDream@darkGreen-tangerineDream/state`; mounted into the sandbox as `/usr/local/darkGreen-/tangerineDream/_state` | mounted view: `/usr/local/darkGreen-/tangerineDream/_state/review` |
| `@darkGreen-tangerineDream-green` (sandbox) | on salt: `/zsalt/var-/tangerineDream-green@darkGreen-tangerineDream-green/state`; mounted as `/usr/local/darkGreen-/tangerineDream-green/_state` | mounted view: `/usr/local/darkGreen-/tangerineDream-green/_state/review` |

- **Pattern (sandbox view):** `REVIEW_EXCHANGE_STATE_DIR = /usr/local/${SPICE_NAMESPACE}-/${SYSTEM_BASE_NAME}/_state/review`, dictated by the shared volumes in `docker-compose.darkGreen-tangerineDream-base.yml` (in the `@tangerineDream` repository): the `_state` mount is one of the per-system bind mounts (`_runtime`, `_cache`, `_state`, `_share`), so `_state` is the bare state root inside the sandbox and `_state/review` is the review dir (the env var value). This matches the `opencodeBase` bridge mapping `_state/opencode` → `.local/state/opencode` (§1 fact 11).

**Syncthing transport (per-top-level-folder simplex pairs — D2.1):**

Each top-level shared folder (Projects, Documents) carries its own raw→processed pair. The review-exchange reuses the **artifact-aggregator** mirror model (`move → mirror → symlink-back`), extended from `node_modules` to a project-local `.local-artifacts` dir.

| Top-level | Raw (forward, @creamsoda→@salt) | Processed (return, @salt→@creamsoda) |
|---|---|---|
| Projects | `rut-Projects_artifacts` = `Projects/.artifact` | `rut-Projects_artifacts_processed` = `Projects/.artifacts--processed` |
| Documents | `rut-Documents_artifacts` = `Documents/.artifacts` | `rut-Documents_artifacts_processed` = `Documents/.artifacts--processed` |

- **In scope:** the **Projects** pair. Review payloads live under a **`review`** subfolder (D3.2): raw = `Projects/.artifact/<project>/.local-artifacts/review/` (laptop→PC); processed = `Projects/.artifacts--processed/<project>/review/` (PC→laptop, later task).
- **Mirror model:** `Projects/.artifact` is the centralized raw mirror — each project's `node_modules` and `.local-artifacts` are mirrored into it, with the project-local originals symlinked back. Symlink targets are **absolute** (aggregator `.resolve()`).
- **Plural naming:** `.artifacts` everywhere except the legacy `Projects/.artifact` (singular — too expensive to rename).
- **Ignore rules for `rut-Projects`** (bidirectional, both hosts): **`.local-artifacts`** (unanchored) and **`/.artifacts--processed`** (root-anchored). `Projects/.artifact` is auto-excluded as a nested Syncthing folder. Documents pair is out of scope.

**Transport-mount distinction (verified against `lib/runtime-home-bridge/default.nix` — §1 facts 10–13):**

- **`_state` is a bridge mount (confirmed).** `opencodeBase` maps `_state/opencode` → `.local/state/opencode` under `namespaceRoot`, so the review state dir is `/usr/local/darkGreen-/<base>/_state/review` (the D7 value). `_state/…` resolves via `source` → `${namespaceRoot}/${source}` (sandbox view).
- **Local reviews (`@salt` producer) — the bridge exposes `@salt`'s OWN projects.** `darkGreen-tangerineDream` `baseForSwitch` = `{ zSource = "shared-/@salt/Projects"; source = "Projects"; target = ".bookmarks/projects"; }` (**switch-time only**), i.e. `@salt`'s own `Projects` (`shared-/@salt/Projects`) mounts into the sandbox as `…/Projects`. `darkGreen-tangerineDream-green` maps **only** `Projects/--personal/AiAssistance__` (no full `Projects`).
- **Work reviews (`@creamsoda` producer) — NOT exposed by the bridge.** The synced transport lives under `/zsalt/shared-/@creamsoda/Projects/.artifact/…` (`rut-Projects_artifacts`, receiveonly). This `@creamsoda` tree is **absent from the bridge catalogs**, so the runtime-home-bridge does **not** mount it into the sandboxes — it requires a **separate docker-compose volume** in the `@tangerineDream` repo (see Diagram C §10).

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
3. **Changed-file inventory → `locations[]`** (deterministic given OIDs): `git diff --no-renames --unified=0 <baseOid> <headOid>`; for each changed path compute head-side (added/modified) or base-side (deleted) hunk line span. Binary/mode-only/rename-only with no hunk → **omit**.
4. MR capture (optional): if `--mr` given, call `gitlab.py` (§3.3). Else `discussionCapture = {"complete": true}`, `discussions = []`.
5. `projectContext`: from `--project-context` files.
6. Compose `payload` with exact schema field names.
7. Identity: `reviewId = "<repo-id>-<baseOid[0:12]>..<headOid[0:12]>"` (overridable); `messageId = "ctx-<reviewId>-<epochMillis>-<uuid4[0:8]>"`; `supersedesMessageId` only when `--supersedes` given.
8. Envelope: `schemaVersion:"1.0"`, `createdAt = iso_now()`, `producer:"laptop"`, `kind:"context_snapshot"`, `payload`, `artifacts`.
9. `artifacts[]`: copy to `assets/<basename>`, compute `sha256` + `sizeBytes`, `mediaType` via `mimetypes.guess_type`.
10. Self-check: run the consumer schema-validation step (§5.1) before publishing; `--dry-run` prints JSON and exits 0 without publishing; otherwise hand off to `stage.py` (§3.4).

### 3.3 `gitlab.py` — MR + paginated discussions/notes

**Behavior:** encode project path; `glab api --hostname instance "projects/$enc/merge_requests/$iid"` → map snake→camel (`instanceUrl`, `projectPath`, `iid`, `webUrl`, `title`, `description`, `sourceBranch`, `targetBranch`, `diffRefs`). **G1 trigger** on missing/malformed `diff_refs`. Discussions paginated with `MAX_PAGES` guard; `discussionCapture.complete` only if the loop ends cleanly; `locationId` only when a note's `position` maps to a `locations[]` id.

### 3.4 `stage.py` — assemble → verify → atomic publish directly to the transport location (no staging hop)

**Inputs:** `--package-dir <dir>`, `--publish-root` (default `./.local-artifacts/review`), `--dry-run`.

**Behavior (mirrors README sync rules 1–5; D3.1 — no separate staging dir):**

1. Assemble the package under the **final transport location** directly: `<publish-root>/<reviewId>/<messageId>/` with `message.json` + `assets/`. No staging dir.
2. **Write artifacts first, JSON last** (readiness signal = JSON present and self-consistent).
3. Verify: recompute each `artifacts[]` `sha256` + `sizeBytes`; mismatch → fail.
4. Atomic publish: `mkdir -p "<publish-root>/<reviewId>/"`; write to `.<messageId>.part/` then rename → `<publish-root>/<reviewId>/<messageId>/`. Never overwrite an existing `messageId` dir.
5. `--dry-run` prints the final layout + SHA results and exits before any write.

### 3.5 Determinism — stated honestly

- **Deterministic core:** `baseOid`/`headOid`, the diff-derived `locations[]`, and captured MR/discussion fields.
- **Vary by design:** `capturedAt` and `messageId`. A changed comparison yields a new `reviewId`. MR discussions are a point-in-time snapshot.

---

## 4. OpenCode commands (run on any consumer host — `@salt` or a sandbox — **no GitLab credentials**)

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
and the checkout is `.` (no host path, no repo-map).

Target selection (maps to `comparison.selection` + OID matching):

- `/review`                 → newest complete `context_snapshot`.
- `/review --branch <name>` → resolve `<name>` to a full OID; locate the
                              package with `selection == "branch"` and `headOid == <oid>`.
- `/review --range <base> <head>` → resolve both to full OIDs; locate the
                              package with `selection == "range"`, `baseOid == <base>`, `headOid == <head>`.

Execute (in order; any failure stops):

    invoke review-exchange locate $LOCATE_ARGS            # reads ./.local-artifacts/review/
    invoke review-exchange validate --package <found message.json> \
        --schema ~/.config/review-exchange/review-exchange.schema.json \
        --repo-root .
    invoke review-exchange materialize --context <found message.json>
        # NO --out-dir: materialize derives materialized/<messageId>/
        # under $REVIEW_EXCHANGE_STATE_DIR (= <state-root>/review) (D6.1/D7)

The dedicated review agent then reads the materialized `base..head` diff plus
the validated context and produces findings against committed code only.
```

> **Follow-up (O2):** the `materialize` line above **drops `--out-dir`** (v2 still hardcoded `--out-dir ~/.local/state/review-exchange/materialized/`). The command markdown must be updated accordingly, and the nix layer must export `REVIEW_EXCHANGE_STATE_DIR` per host — flagged for the **nix/config agent** (out of scope for this document). The schema path in `validate --schema` stays `~/.config/review-exchange/review-exchange.schema.json` (config, not state — O1 resolved: no rename).

### 4.2 Branch/range/branch-label mapping — clarification

- **"current branch"** is a *laptop-side* concept. The producer's default (`--head $(git branch --show-current)`, `--target main`) yields `selection:"branch"` with `baseOid = merge-base(target, head)`. On `@salt`, `/review` with no args takes the newest complete package.
- **"range"** = explicit `base..head` → `selection:"range"`, both OIDs pinned.
- **"specific branch"** = `selection:"branch"` with `headLabel` = branch name.
- The robust join key is always the **full OID pair**; `baseLabel`/`headLabel` are informational and must never be used to resolve code.

---

## 5. "Understand the payload" tasks (run on any consumer host, from inside the project/worktree)

### 5.1 `validate.py` — structural + semantic + integrity + identity

**Inputs:** `--package <message.json>`, `--schema <path>`, `--repo-root <dir>` (default `.`), `--index <dir>` (default: `<state-root>/review/imported/` — D7; see §5.1.1), `--allow-missing-objects`.

**Behavior (mirrors README sync rules 1–6):**

1. JSON parse; reject on parse error.
2. Reject unsupported `schemaVersion` (must be `"1.0"`).
3. **Schema validate** with `check-jsonschema` (draft 2020-12, `format` on). `additionalProperties:false` everywhere.
4. **Integrity:** verify each `artifacts[]` `sha256` + `sizeBytes` against the package-relative file.
5. **Dedup by `messageId`:** against `--index`; identical bytes → skip; same ID different bytes → conflict → fail; unknown → record.
6. **Supersession:** require same-kind/same-review parent; detect cycles, missing parents, concurrent successors → fail.
7. **Semantic references:** `contextMessageId`/`resultMessageId`/`findingIds`/`locationIds`/`artifactIds`/`discussionId`/`target.locationId` resolve; `reviewId` consistency; `1 ≤ startLine ≤ endLine`; `side`∈{base,head}.
8. **Identity consistency (replaces the path lookup — D3.3):** confirm `payload.repository.id` corresponds to the repo the consumer is in (cwd) — project dir name and/or a marker/remote in `.git/config`. Never produces a checkout path.
9. **Path containment (incl. symlinks):** `location.path` inside `--repo-root`; `artifact.path` inside the package dir.
10. **URLs:** `instanceUrl`/`webUrl` must be `https://` with no userinfo.
11. **`discussionCapture.complete == false`** ⇒ `omissionReason` present.
12. Exit 0 or non-zero with a machine-readable failure list.

> **Index writes (D6.2):** when `validate` records a new `<messageId>.json` index entry (and when `supersession_check` updates chain links), the write must be **atomic** — write to a temp file in `imported/`, then `os.replace()` into `<messageId>.json`. This guarantees `supersession_check`/`locate`'s `glob` never reads a half-written file (concurrent consumers on one home).

### 5.1.1 Dedup-index default — resolved by D7

**Resolved (was open in v2).** `validate --index` now defaults to `<state-root>/review/imported/` (the dedup/supersession index dir), where `<state-root>/review` is the value of `REVIEW_EXCHANGE_STATE_DIR` (D7). This replaces the v2 open question: v2's option (a) ("Python-level default `~/.local/state/review-exchange/imported/`") is **superseded** — the default is now the D7 state dir (`<state-root>/review/imported/`), still overridable, still per-`$HOME`-equivalent (per-host), and matching `materialize`'s state-root-derived output. The core reads the env var; the portable `~/.local/state/review` fallback is for manual runs only.

**Multi-consumer implication (D4 + D7).** The index **must** be per-host (per consumer), never shared. `@salt`, `@darkGreen-tangerineDream`, and `@darkGreen-tangerineDream-green` each maintain their own `<state-root>/review/imported/` (each its own `REVIEW_EXCHANGE_STATE_DIR`). A shared index would let one consumer's import mark a message "duplicate" for all others and pollute the supersession chain with cross-host state.

### 5.2 `materialize.py` — verify OIDs in the cwd checkout, produce per-review diff

**Inputs:** `--context <message.json>`, `--fetch` (optional). No `--out-dir`, no `--repo-map`; the checkout is `.` (cwd). **Output dir is derived (D6.1/D7):** `<state-root>/review/materialized/<messageId>/`.

**Behavior:**

1. Confirm cwd is a Git worktree: `git -C . rev-parse --git-dir`; fail otherwise.
2. **Verify exact code:** `git -C . cat-file -e "<baseOid>^{commit}"` and `"<headOid>^{commit}"`. On missing object → print `missing-objects: <oid>`, flag as **not materializable**, stop. Optional `--fetch` runs `git fetch origin <headOid>` (producer-side recovery knob; expected to fail on a consumer — G4).
3. **Committed snapshots only:** never include working-tree edits; warn if `git -C . status --porcelain` shows local edits.
4. **Produce the reviewable diff into `materialized/<messageId>/`** (per-review, D6.1): `git -C . diff --no-color <baseOid> <headOid>` → `diff.patch`; `git -C . diff --stat` → `diffstat.txt`; `git -C . log --oneline <baseOid>..<headOid>` → `commits.txt`. `mkdir -p` the dir first (may not exist, D7).
5. Cross-check `locations[]` line ranges against the actual blob; flag any `endLine` exceeding the blob line count.

> **Concurrency (D6.1).** Because the output dir is keyed by `messageId`, two agents reviewing different projects/diffs on the **same** home write to different `materialized/<messageId>/` dirs and never collide. A fixed dir (v2's `~/.local/state/review-exchange/materialized/`) would let concurrent runs overwrite each other's `diff.patch`/`diffstat.txt`/`commits.txt`.

> **Producer / consumer roles (D5).** Fetch is a **producer** capability, never a consumer one. Consumers never fetch; a missing OID is a hard "not materializable" flag (G4). The shared `rut-Projects` checkout supplies the OIDs via the synced `.git`; it is **not** a per-consumer object store.

### 5.3 `locate.py` — find the newest complete package

**Inputs:** `--publish-root` (default `./.local-artifacts/review` — cwd-relative; no host path, D3.4), `--kind context_snapshot`, `--review-id <id>`, `--head-oid`/`--base-oid`.

**Behavior:**

1. Resolve `--publish-root`; enumerate `<publish-root>/<reviewId>/<messageId>/message.json`, skipping `.part` temp dirs.
2. Consider "complete" only if JSON parses and all `artifacts[]` are present with matching SHA (reuse §5.1 steps 1–4).
3. Filter by `--kind` and by OID match when supplied.
4. Exclude superseded messages.
5. Sort by `createdAt` (RFC3339 lexicographic) and emit the newest path.

---

## 6. Run-from-project + identity consistency (no repo-map)

The message carries only `payload.repository.id` + `displayName` — **identity only**. No `repo-map.json`, no `repository.id → checkout` resolution (D3.3).

**Run-from-project model.** The consumer is invoked **from inside** the project/worktree. The current working directory is the single authoritative anchor:

- **Package location:** `./.local-artifacts/review/` — the project-local symlink → the centralized mirror.
- **Git checkout:** `.` (cwd) — `cat-file -e`, `git diff base..head`, `git log`, `git show`.
- **Containment root:** `.` (cwd).

**Identity consistency check (§5.1 step 8).** `validate` compares `payload.repository.id` against the project directory name and/or a marker/remote in `.git/config`. A mismatch is a validation failure (wrong-repo guard).

```text
Projects/                        # rut-Projects (bidirectional)
├── .artifact/                   # rut-Projects_artifacts — centralized raw mirror (sendonly)
│   └── auto-hub/
│       ├── .local-artifacts/    # mirrored raw artifacts (real dir)
│       │   └── review/          # ← transport: ./.local-artifacts/review/ via symlink
│       └── CurrentTask1/node_modules/
├── .artifacts--processed/       # rut-Projects_artifacts_processed — centralized processed (sendonly)
│   └── auto-hub/
└── auto-hub/                    # a project (worktree root) — consumer cwd for git/containment
    ├── Analytics                # worktree
    ├── CurrentTask1             # worktree (e.g. `cd` here to run /review)
    ├── Main -> …/AutoHub.git    # worktree (name arbitrary)
    ├── .local-artifacts -> …/Projects/.artifact/auto-hub/.local-artifacts   # symlink → mirror
    ├── .artifacts--processed/   # project-local processed (agent consumption)
    └── … (_configs, _http, _scripts, _utils, node_modules, shared-scripts, yarn.lock, …)
```

- The consumer runs `git -C .` from the chosen worktree; `cat-file -e` for both OIDs works without any mapping.
- `repository.id`/`displayName` remain in the payload for stable `reviewId`, findings attribution, and dedup/supersession — never for path resolution.

---

## 7. Gates — all operator decisions resolved

Standing constraints (never violated):

- **G1 — contract conformance.** Any GitLab field (notably `diff_refs.*`) that cannot map 1:1 → **STOP and escalate to Architect**; do not extend the schema.
- **G2 — credential hygiene.** Token read only via `$GITLAB_TOKEN` / `glab api`; never serialized; no credential-bearing URLs in payload.
- **G3 — repo mapping machine-local.** Satisfied by the run-from-project model + identity check (§6), not a `repo-map.json`.
- **G4 — OID materialization.** `cat-file -e` both OIDs in the cwd checkout; missing objects are **flagged**, not silently replaced.
- **G5 — Syncthing transport/SHA/dedup/containment + atomicity.** Producer: direct write to transport — artifacts then JSON → SHA verify → atomic rename (no staging dir, D3.1). Consumer re-validates SHA, dedup by `messageId`, containment incl. symlinks, supersession-cycle detection. **New in v3:** consumer index writes are atomic (temp + rename, D6.2), and `materialize` output is per-review (D6.1).
- **G6 — scope boundary.** `jira`/`sentry`, and production/publication of `review_result`/`investigation_request`, are **out of scope**. The return-transport **folder** `Projects/.artifacts--processed` is reserved only.

Resolved (see §0 for full detail): return-transport folder (D2.1); validator toolchain (D2.2); `reviewId`/`messageId` scheme (D2.3); `/review` `agent:` (D2.4); producer approach (A); drop staging hop (D3.1); transport folder `review` (D3.2); drop `repo-map.json` (D3.3); `/review` as generic harness command (D3.4); per-review `materialize` output (D6.1); atomic index writes (D6.2); state-dir relocation + `REVIEW_EXCHANGE_STATE_DIR` (D7).

---

## 8. Ordered steps with ownership

1. **Core package (Layer 1)** `shared-scripts/_features/packages/review-exchange/` — `git_ops`, `gitlab`, `capture`, `stage` (direct-write), `validate` (identity check + **atomic index writes**, D6.2), `materialize` (cwd checkout + **per-review `materialized/<messageId>/` output**, D6.1), `locate` (cwd-relative), **`state` (read `REVIEW_EXCHANGE_STATE_DIR` (= `<state-root>/review`), D7)**. **No `repo-map.json.template`.** Verify: unit tests per module; `capture --dry-run` on a real checkout.
2. **Invoke wrapper (Layer 2)** `shared-scripts/review_exchange.py`. Verify: `invoke review-exchange --help` lists all tasks.
3. **Consumer tasks** `validate`/`materialize`/`locate`. Verify: run against `context.example.json` (structural pass) and a deliberately corrupted copy; confirm identity-consistency fails on a mismatched `repository.id`; confirm `materialize` writes into `materialized/<messageId>/` (not a fixed dir) and that index entries are written atomically (no half-written file observable).
4. **Command** `modules/home/apps/ai-assistance/opencode/commands/review.md` (generic harness; `agent: review-agent`). Verify: `--dry-run` resolves `locate` from `./.local-artifacts/review/` and stops before mutation; grep for any hardcoded host path or `--repo-map` (absent) **and for any `--out-dir` (absent — O2)**.
5. **Thin TS tools (Layer 3)** `review-exchange.nix` + `${AiAssistanceDir}/_tools/`. Verify: `nix flake check` / narrowest home-manager eval.
6. **Host glue + env var (D7):** enable `role = "producer"` on `apakalo@creamsoda`; `role = "consumer"` + schema copy + `customTools.review-exchange` on **every consumer host** (`ds13@salt` **and** the sandboxes `tangerineDream@darkGreen-tangerineDream` and `tangerineDream-green@darkGreen-tangerineDream-green`). **Set `REVIEW_EXCHANGE_STATE_DIR` per host** to the §2.1 value (salt vs sandbox). Install the schema copy only (**no `repo-map.json`**). Verify: narrowest home-manager eval per `AGENTS.md`; confirm the env var resolves to the §2.1 path per host.
7. **Syncthing**: add the processed folder `Projects/.artifacts--processed` (receiveonly @creamsoda / sendonly @salt); add `.local-artifacts` (unanchored) and `/.artifacts--processed` (root) to `rut-Projects` `ignorePatterns` on both hosts.
8. **End-to-end dry run**: producer snapshot → `validate` passes on the salt copy (identity check OK) → `materialize` reports `cat-file -e` success for both OIDs and writes into `materialized/<messageId>/` under the resolved state root.

**Affected files/interfaces:** new `_features` package (no `repo-map.json.template`; + `state.py`), `review_exchange.py`, `review-exchange.nix`, `modules/home/apps/ai-assistance/opencode/commands/review.md` (drop `--out-dir`), a dedicated review-agent definition, producer glue + per-consumer glue edits (schema copy + `customTools.review-exchange` + **`REVIEW_EXCHANGE_STATE_DIR`** on `ds13@salt` **and** both sandbox homes, D4/D7), two Syncthing `default.nix` edits. No changes to `glab`, `gitlab.nvim`, or the schema. **No data migration.** **Rollback:** delete the module enable flags + command + agent + env var; tasks are additive and leave state only under `<state-root>/review/` and the `Projects/.artifact` / `Projects/.artifacts--processed` transport dirs (transport subfolder `review`).

---

## 9. Validation / acceptance criteria

| Item | Criterion |
|---|---|
| Schema conformance | `validate` returns 0 on `context.example.json` (structural); rejects unknown field / wrong `schemaVersion`/`oid`/`date-time`/`uri`/`path`. |
| Determinism | two `capture --dry-run` runs on unchanged OIDs produce identical `comparison`, `locations`, `reviewId` (only `capturedAt`/`messageId` differ). |
| Code availability | `materialize` `git -C . cat-file -e` succeeds on both OIDs in the cwd checkout; missing OID → `missing-objects` flag + non-zero exit. |
| Identity consistency | `validate` fails when `payload.repository.id` does not match the current repo; a correct match passes. No path resolution occurs. |
| Run-from-project | `locate` finds `./.local-artifacts/review/` with no `--repo-map` and no hardcoded host path; the consumer runs entirely from cwd. |
| Multi-consumer | the same synced package is consumable independently by `@salt` and each sandbox; each consumer keeps its own `<state-root>/review/` (D7) index + materialized output (no cross-host sharing, D4). |
| Transport folder | all synced transport paths use `review` (`.local-artifacts/review/`, `.artifacts--processed/review/`); `review-exchange` appears only as contract-dir/package/tool/config naming, never as a synced folder or a state dir. |
| No staging hop | the producer writes directly to the transport location; no staging dir exists or is referenced. |
| Per-review materialize output (D6.1) | two concurrent `materialize` runs for different `messageId`s write to distinct `materialized/<messageId>/` dirs; no cross-contamination of `diff.patch`/`diffstat.txt`/`commits.txt`. |
| Atomic index writes (D6.2) | an index write is observable only as a complete `<messageId>.json` (temp-then-rename); a concurrent `glob`/`supersession_check` never sees a half-written file. |
| State dir + env var (D7) | `materialize`/`validate` resolve their dirs from `REVIEW_EXCHANGE_STATE_DIR`; unset → `~/.local/state/review` fallback (manual runs); the dirs are `mkdir -p`'d on first use. Per-host paths match §2.1. |
| Integrity | every `artifacts[]` SHA-256 + `sizeBytes` recomputed and matching; tampered artifact fails. |
| Dedup/supersession | duplicate `messageId` (different bytes) → conflict; supersession cycle/missing parent → fail. |
| Containment | a `location.path` escaping the cwd root, or an `artifact.path` escaping its package dir (incl. via symlink), is rejected. |
| Credentials | grep of a produced snapshot + logs shows no `glpat-`, no `GITLAB_TOKEN` value, no `@`-credential URLs. |
| Dry-run | `--dry-run` performs full compute + validation but writes nothing to any Syncthing transport root. |
| Scope | `jira`/`sentry` fields and `review_result`/`investigation_request` producers are absent (G6). |
| No shell | runtime path contains no `bash`/`jq`/`shasum` dependencies; git plumbing via `git` CLI, GitLab via `glab api`, JSON via Python stdlib. |

---

## 10. Diagrams

Three PlantUML diagrams (`.puml`, rendered to `.svg`) live in `.agents/review-exchange-v1/diagrams/`:

- **A — review process + when commands are sent** → [`diagrams/review-process.puml`](./diagrams/review-process.puml). Sequence diagram across the logical actors **Producer agent**, **Transport** (Syncthing `rut-Projects_artifacts` / shared filesystem), **Consumer agent** (runs `/review`), and **review-agent**, in four ordered phases: Phase 0 capture (explicit), Phase 1 transfer (automatic), Phase 2 open/investigate (explicit: `locate` → `validate` → `materialize`), Phase 3 review (review-agent reads materialized diff + validated context), Phase 4 return (explicit, later; out of scope — `Projects/.artifacts--processed/review` reserved only).
- **B — dedup/supersession + materialize data flow** → [`diagrams/dedup-supersession-materialize.puml`](./diagrams/dedup-supersession-materialize.puml). Data-flow diagram across **Producer**, **Transport** (`.local-artifacts/review/`), **Consumer validate**, **Dedup/supersession index** (`imported/`), **Consumer materialize**, **materialized output** (`materialized/<messageId>/`), **git checkout** (cwd), and **review-agent**. Shows A1 then A2 (`supersedesMessageId = A1`); validate writing `<messageId>.json` (sha256) and following the supersession chain (missing parent / cycle / concurrent successor); materialize reading context, running git in cwd (`cat-file -e` + `git diff base..head`), and writing `diff.patch`/`diffstat.txt`/`commits.txt`; review-agent reading that output. Notes call out the two D6 invariants (atomic index writes, per-review output).
- **C — end-to-end flow with filesystem forensics** → [`diagrams/review-flow-forensics.puml`](./diagrams/review-flow-forensics.puml) ([`.svg`](./diagrams/review-flow-forensics.svg)). A single concrete scenario — producer `@creamsoda` → consumer `@darkGreen-tangerineDream-green`, with the data reaching the sandbox **via a mount onto `@salt`'s filesystem** — showing concrete paths at each hop: the producer worktree + project-local `.local-artifacts` **symlink → mirror** (`/Users/apakalo/Projects/<project>/.local-artifacts` → `/Users/apakalo/Projects/.artifact/<project>/.local-artifacts/`); Syncthing `rut-Projects_artifacts` (sendonly `/Users/apakalo/Projects/.artifact` → receiveonly `/zsalt/shared-/@creamsoda/Projects/.artifact`); `@salt` filesystem shared with the sandbox via docker shared volumes; and the consumer state-dir volume mount (`/usr/local/darkGreen-/tangerineDream-green/_state/review` ↔ `/zsalt/var-/tangerineDream-green@darkGreen-tangerineDream-green/state/review`) holding `imported/` + `materialized/<messageId>/`. Includes the producer-generality note and records the transport-mount distinction (§1 facts 10–13 / §2.1): the bridge confirms the `_state` mount and `@salt`'s own projects, but the `@creamsoda`-synced transport (`/zsalt/shared-/@creamsoda/Projects/.artifact`) is **not** exposed by the bridge — it is a separate docker-compose volume (external).

---

## 11. Open questions / follow-ups (O1 resolved; O2 open)

- **O1 — schema-copy rename — RESOLVED (operator, 2026-10-27).** Keep `~/.config/review-exchange/review-exchange.schema.json` as-is (no rename). It is **config, not state**, so D7 does not move it.
- **O2 — `/review` `--out-dir` drop (nix/config-agent follow-up).** The `/review` command must drop `--out-dir` (D6.1/D7); the nix layer must export `REVIEW_EXCHANGE_STATE_DIR` per host. Assigned to the nix/config agent (out of scope here).
