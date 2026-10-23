# 0007 — Agent-harness iteration from inside the sandbox, with merge gates

- **Status:** Accepted (human gate G-ARCH; G-ENV accepted; implement)
- **Date:** 2026-10-18
- **Task:** HARNESS-ITER-001 · **Project:** AiAssistance__/Harness
- **Supersedes:** ADR-HARNESS-ITER-001 R1 (capability tiers) — proposal withdrawn
- **Source:** shared Discovery brief HARNESS-ITER-001 R3 (VALIDATED)
- **Related:** ADR 0003 (inner system/inner home), ADR 0005 (agent roles / Logseq access), ADR 0006 (child-flake & repo policy), RFC `docs/rfc/agent-child-flake-inheritance.md`

## Context

Containerized agents iterate on the agent harness from inside the Docker/NixOS
sandbox, where the most context exists. `_inner` is the editable surface and may
drift from the outer/real harness; promotion to the real harness is a deliberate,
human-driven, host-side operation. The sandbox border must not be weakened.

An earlier revision (R1) tried to make the inner/outer edit boundary a
*permission* boundary: T0/T1/T2 tiers, a bash/edit floor, a fragment-only
subagent, and a separate static oracle. That was rejected: nearly every agent
already has `bash`, so edit-scoping is false assurance. The real control is the
**sequence of gates plus a human**. This revision is a reduction that keeps the
mechanism that works.

## Decision

### D1 — T1 `darkGreen-inner-conv-plat-prov`: primary, namespace-generated, Logseq-producing

- `mode: primary` (**main-only**, not delegable). Derived from the `nix-build` shape.
- Name `<spiceNamespace>-inner-conv-plat-prov` (currently `darkGreen-inner-conv-plat-prov`),
  generated from `common.{spiceNamespace,systemBaseName}`.
- Persona: [`agents/darkGreen-inner-conv-plat-prov.md`](../../modules/home/apps/ai-assistance/opencode/agents/darkGreen-inner-conv-plat-prov.md).
- The inner provisioner/verifier and the only inner writer **by convention**.
- Logseq-producing: own tree `ai-ihp InnerHarnessProvisioning_system`; instance
  `logseq-darkGreen-inner-conv-plat-prov` (18124) + summarizer
  `logseq-summ-darkGreen-inner-conv-plat-prov` (18125); add the key to `producingParents`.
- `checks/mcp-logseq` count/name list grows 17 → 19.

### D2 — `harness-conv-plat-prov`: subagent, the single door

- `mode: subagent`, namespace-agnostic, no Logseq, no port. The SINGLE DOOR for harness edits.
- Persona: [`agents/harness-conv-plat-prov.md`](../../modules/home/apps/ai-assistance/opencode/agents/harness-conv-plat-prov.md).
- Callable by every agent: delegators add `permission.task."harness-conv-plat-prov" = "allow"`.
- `bash`: read-only + `git` + `nix flake check` allowlist (default deny; no `sudo`,
  `nixos-rebuild`, `home-manager`, `nix develop`/`shell`/`build`, network, or push).

### D3 — Path-scoped no-ask (the one real permission change)

Because the repo is outside the workspace, the per-edit prompts come from the
`external_directory` guard (default `ask`), not `edit`:

```nix
# spiceNamespace/systemBaseName come from `common` (systemBaseName falls back
# to the home username), so the sandbox path is derived, never hardcoded.
permission.external_directory = {
  "/usr/local/${spiceNamespace}-/${systemBaseName}/_configs/Unix_dotfiles/**" = "allow";
  "~/.bookmarks/shared-configs/Unix_dotfiles/**" = "allow";
};
```

Scope: the `Unix_dotfiles` repo subtree (parent + child copy `ai-/…`), never `~`.
Carried by both provisioners, together with a fail-closed `bash` allowlist
(read-only inspection + read-only git + the permitted Nix checks); `bash` can
still bypass `edit` — this is UX, not a boundary.

### D4 — Merge direction (i) and review-state merge

- Host: `git fetch "$CHILD"` then `git merge --no-commit --no-ff <ref>` into parent `dev`,
  **stopping** in a reviewable merge state (print `git status` / `git diff --cached`).
- Bounded: landed delta ⊆ `**/systems/*/*_inner/**` ∪ `**/homes/*/*_inner/**`; abort otherwise.
- Abort on conflict; **never auto-resolve**. Agent reviews the ACTUAL code with the human.
- Promotion is a **separate** phase over layout-derived targets.
- Rollback: pre-commit `git merge --abort`; post-commit `git revert -m 1 <merge>`.

### D5 — Layout-derived targets (Workstream C)

Compute propagation targets from the snowfall layout at run time; carry only a small
classification→selector mapping in the `change-proposal` manifest. No hand-maintained registry.

### D6 — `/merge-harness` and gates

`/merge-harness` is the `harness.merge` **invoke task** in `tasks/harness/`; the opencode
command and the `make harness-merge` target are thin wrappers. It runs on the host in the
real parent repo; the child checkout is created by `harness.bootstrap`
(`/bootstrap-child-flake`). Steps: discover → classify → plan [gate] → merge (review-state) →
host review [gate] → commit → separate promotion → verify → report/rollback. The host gate is
the HARD boundary; agent permissions are cooperative.

Gate sequence: inner-write (only T1) → inner verification → commit/manifest → host review →
build/deploy.

### D7 — Verification checklist (T1/T2, before a change is "ready")

- `nix flake check`; `nix eval` of changed attrs.
- Dry builds: `nixos-rebuild build --flake .#<sys>_inner`, `home-manager build`.
- Behavioral proof in-sandbox: `nixos-rebuild switch`, then assert the capability appeared.
- Change ↔ acceptance criterion ↔ evidence mapping; risk + rollback; cleanliness.

### D8 — Bootstrap

Obtain the git CLI ephemerally: `nix shell nixpkgs#git` (human-run). No image guarantee, no
`path:` fallback.

## Consequences

- ADR 0003 inner/outer model unchanged. ADR 0005 decisions 2–11 unchanged; this ADR does **not**
  add a permission-tier class. ADR 0006 child-flake policy + merge direction (i) kept.
- Existing agents keep their current `bash`/`edit` permissions.
- Prohibited: altering `secrets/`, `.sops.yaml`, `deploy.nodes`, unrelated hosts/users, or private
  inputs; scaffolding merging back; auto-resolving merges.
