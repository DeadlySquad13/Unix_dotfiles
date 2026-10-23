"""Host-side invoke tasks for agent-harness iteration.

This collection replaces the former ``scripts/bootstrap-child-flake.sh`` and
``scripts/merge-harness.sh``.  It implements ADR 0006 §3 / ADR 0007
D4/D5/D6/D8: one blobless sparse child checkout per agent
(``ai-/<spice>-/<agent>``), and a bounded, review-state merge of the child's
``_inner`` delta into the parent repo.

Run from the host in the real parent repo::

    invoke --search-root=./tasks harness.bootstrap [--dry-run]
    invoke --search-root=./tasks harness.merge --dry-run
    invoke --search-root=./tasks harness.merge
    invoke --search-root=./tasks harness.merge --promote
    invoke --search-root=./tasks harness.classify
    invoke --search-root=./tasks harness.selfcheck

``make harness-*`` targets wrap these; the ``/merge-harness`` and
``/bootstrap-child-flake`` opencode commands are thin wrappers too.

``harness.merge`` is the host HARD gate: it stops in a reviewable merge state
and waits for a human.  It never auto-resolves a conflict and never
force-pushes.  Promotion to the outer (image-baked) surface is a separate
phase.

Classification data lives next to this module: ``classify.json`` (shared) and
an optional ``classify.override.json`` (host-local, merged over the shared
map).
"""

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from glob import glob
from pathlib import Path

from invoke import Context, task

MODULE_DIR = Path(__file__).resolve().parent
CLASSIFY_PATH = MODULE_DIR / "classify.json"
OVERRIDE_PATH = MODULE_DIR / "classify.override.json"
GIT_FALLBACK_GLOB = "/nix/store/*-git-*/bin/git"

DEFAULT_SPICE = "darkGreen"
DEFAULT_AGENT = "tangerineDream-green"

# Child scaffolding is intentionally untracked and must never merge back.
SCAFFOLDING_EXCLUDES = ("flake.nix", "flake.lock", "/lib/inherit/")


# --------------------------------------------------------------------------- #
# output / process helpers
# --------------------------------------------------------------------------- #
def _die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def _log(title: str) -> None:
    print(f"\n== {title} ==")


def _info(msg: str) -> None:
    print(f"   {msg}")


def _git_bin() -> str:
    """git from PATH, else the newest /nix/store build (host/sandbox parity).

    Mirrors ``tasks/opencode/debug.py`` and ``tasks/packages/debug.py`` so the
    tasks work in the container where ``git`` is not guaranteed on PATH.
    """
    which = shutil.which("git")
    if which:
        return which
    fallbacks = sorted(glob(GIT_FALLBACK_GLOB))
    if fallbacks:
        return fallbacks[-1]
    _die("no git binary found (PATH and /nix/store)")


def _run(argv, *, dry_run: bool = False, capture: bool = False,
         check: bool = False, cwd=None, quiet: bool = False):
    shown = " ".join(str(a) for a in argv)
    if dry_run:
        print(f"[dry-run] {shown}")
        return subprocess.CompletedProcess(argv, 0, "", "")
    if not quiet:
        print(f"+ {shown}")
    result = subprocess.run(
        [str(a) for a in argv],
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=capture,
    )
    if check and result.returncode != 0:
        _die(f"command failed (rc={result.returncode}): {shown}")
    return result


def _git(args, *, repo=None, dry_run: bool = False, capture: bool = False,
         check: bool = False, quiet: bool = False):
    argv = [_git_bin()]
    if repo is not None:
        argv += ["-C", str(repo)]
    argv += list(args)
    return _run(argv, dry_run=dry_run, capture=capture, check=check, quiet=quiet)


def _gate(prompt: str, *, dry_run: bool = False, assume_yes: bool = False) -> None:
    if dry_run or assume_yes:
        _info(f"gate: {prompt} [auto-proceeded]")
        return
    reply = input(f"\nGATE: {prompt}\nContinue? [y/N] ").strip().lower()
    if reply not in ("y", "yes"):
        _info("stopped at host gate (re-run with --yes to proceed)")
        raise SystemExit(0)


# --------------------------------------------------------------------------- #
# classification / layout
# --------------------------------------------------------------------------- #
def _deep_merge(base: dict, override: dict) -> dict:
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            _deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def _load_classification() -> dict:
    if not CLASSIFY_PATH.is_file():
        _die(f"classification map not found: {CLASSIFY_PATH}")
    data = json.loads(CLASSIFY_PATH.read_text())
    if OVERRIDE_PATH.is_file():
        override = json.loads(OVERRIDE_PATH.read_text() or "{}")
        if override:
            _info(f"merging host override: {OVERRIDE_PATH}")
            _deep_merge(data, override)
    return data


def _platforms(cls: dict) -> tuple[str, str]:
    mapping = cls.get("layout", {}).get(
        "systemPlatformMap", {"x86_64-linux": "x86_64-docker"})
    inner = next(iter(mapping))
    return inner, mapping[inner]


def _derived(cls: dict, spice: str, agent: str, user: str) -> dict:
    """Layout-derived paths. Child keeps the spice directory suffix
    (``ai-/darkGreen-/<agent>``); the branch uses the bare namespace."""
    inner_platform, outer_platform = _platforms(cls)
    return {
        "child": f"ai-/{spice}-/{agent}",
        "branch": f"agent/{spice}/{agent}",
        "inner_system": f"systems/{inner_platform}/{spice}-{agent}_inner",
        "inner_home": f"homes/{inner_platform}/{user}@{spice}-{agent}_inner",
        "outer_system": f"systems/{outer_platform}/{spice}-{agent}",
        "outer_home": f"homes/{inner_platform}/{user}@{spice}-{agent}",
    }


def _glob_regex(pattern: str) -> "re.Pattern[str]":
    """Translate a gitignore-ish glob (``**``, ``*``, ``?``) to an anchored regex.

    ``**/`` matches zero or more leading directories; ``**`` matches anything
    (including ``/``); ``*`` and ``?`` never cross ``/``.
    """
    out = ["^"]
    i = 0
    n = len(pattern)
    while i < n:
        ch = pattern[i]
        if ch == "*":
            if pattern[i:i + 2] == "**":
                i += 2
                if i < n and pattern[i] == "/":
                    out.append("(?:.*/)?")
                    i += 1
                else:
                    out.append(".*")
            else:
                out.append("[^/]*")
                i += 1
        elif ch == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(ch))
            i += 1
    out.append("$")
    return re.compile("".join(out))


def _matches(path: str, pattern: str) -> bool:
    if _glob_regex(pattern).match(path):
        return True
    # Root-relative patterns also match at any depth (e.g. lib/inherit/**).
    return _glob_regex(f"**/{pattern}").match(path) is not None


def _promote_path(path: str, cls: dict) -> str | None:
    """Derive the outer (image) target for an inner path, or None.

    Only *systems* move from the inner platform to the outer platform; homes
    keep the inner (linux) platform and only lose the ``_inner`` suffix.
    """
    inner_platform, outer_platform = _platforms(cls)
    match = re.match(rf"^systems/{re.escape(inner_platform)}/(.*)$", path)
    if match:
        path = f"systems/{outer_platform}/{match.group(1)}"
    else:
        match = re.match(rf"^homes/{re.escape(inner_platform)}/(.*)$", path)
        if not match:
            return None
        path = f"homes/{inner_platform}/{match.group(1)}"
    return re.sub(r"_inner(?=/|$)", "", path)


def _is_inner(path: str) -> bool:
    return re.search(r"(^|/)(systems|homes)/[^/]+/[^/]*_inner(/|$)", path) is not None


# --------------------------------------------------------------------------- #
# tasks
# --------------------------------------------------------------------------- #
@task
def bootstrap(
    c: Context,
    parent: str = "",
    spice: str = DEFAULT_SPICE,
    agent: str = DEFAULT_AGENT,
    user: str = "",
    branch: str = "",
    dry_run: bool = False,
):
    """Create the agent child-flake checkout (blobless partial clone, sparse).

    Implements ADR 0006 §3 / ADR 0007 D8.  The clone has its own ``.git``
    (works in-container) and, with ``origin`` removed, cannot lazily fetch
    parent blobs.  Child scaffolding (``flake.nix``, ``flake.lock``,
    ``lib/inherit/``) is excluded via ``.git/info/exclude`` so it can never
    merge back.

    Never deletes an existing checkout: it is moved aside to ``.bak-<ts>``.
    """
    parent_path = Path(parent or os.getcwd()).resolve()
    user = user or agent
    cls = _load_classification()
    derived = _derived(cls, spice, agent, user)
    branch = branch or derived["branch"]
    child = parent_path / derived["child"]
    inner_sys = derived["inner_system"] + "/**"
    inner_home = derived["inner_home"] + "/**"

    print("== bootstrap-child-flake ==")
    print(f"PARENT : {parent_path}")
    print(f"CHILD  : {child}")
    print(f"SPARSE : /{inner_sys}")
    print(f"         /{inner_home}")
    print(f"BRANCH : {branch}")

    probe = _git(["rev-parse", "--git-dir"], repo=parent_path, capture=True, quiet=True)
    if probe.returncode != 0:
        _die(f"{parent_path} is not a git repository")

    if child.exists():
        backup = child.with_name(f"{child.name}.bak-{datetime.now():%Y%m%d%H%M%S}")
        print(f"NOTE: {child} already exists -> moving aside to {backup} (not deleting)")
        if dry_run:
            print(f"[dry-run] mv {child} {backup}")
        else:
            shutil.move(str(child), str(backup))

    # Blobless partial clone from the parent.  --no-local is required for the
    # filter to apply to a local source; --no-checkout lets sparse-checkout be
    # configured before the first checkout.
    _git(["clone", "--no-local", "--filter=blob:none", "--no-checkout",
          "--branch", "dev", str(parent_path), str(child)], dry_run=dry_run, check=True)

    _git(["sparse-checkout", "init", "--no-cone"], repo=child, dry_run=dry_run, check=True)
    _git(["sparse-checkout", "set", "--no-cone", inner_sys, inner_home],
         repo=child, dry_run=dry_run, check=True)
    _git(["checkout"], repo=child, dry_run=dry_run, check=True)

    # Cut origin so the agent cannot lazily fetch parent blobs.
    _git(["remote", "remove", "origin"], repo=child, dry_run=dry_run, check=True)

    # Keep child scaffolding untracked so it never merges back.
    exclude = child / ".git" / "info" / "exclude"
    existing = exclude.read_text() if exclude.is_file() else ""
    missing = [p for p in SCAFFOLDING_EXCLUDES if p not in existing.splitlines()]
    if missing:
        if dry_run:
            print(f"[dry-run] append {missing} to {exclude}")
        else:
            exclude.parent.mkdir(parents=True, exist_ok=True)
            with exclude.open("a") as fh:
                for entry in missing:
                    fh.write(entry + "\n")

    _git(["switch", "-c", branch], repo=child, dry_run=dry_run, check=True)

    print()
    print(f"Done. The child checkout is at: {child}")
    print("Scaffolding (flake.nix / flake.lock / lib/inherit/) is NOT written here;")
    print("generate it in-container against the read-only parent mount (git+file:).")
    print("Next: merge back with `invoke --search-root=./tasks harness.merge`.")


@task
def merge(
    c: Context,
    target: str = "",
    child: str = "",
    spice: str = DEFAULT_SPICE,
    agent: str = DEFAULT_AGENT,
    branch: str = "",
    dry_run: bool = False,
    yes: bool = False,
    promote: bool = False,
):
    """Fetch a bounded inner delta and merge it in review state, with gates.

    Implements ADR 0007 D4/D5/D6.  Runs on the HOST in the real parent repo.
    Steps: discover -> classify -> plan [gate] -> merge (review-state) ->
    host review [gate] -> commit -> separate promotion -> verify ->
    report/rollback.

    ``--dry-run`` changes nothing in the working tree (it may update the
    transient FETCH_HEAD ref so the classification preview reflects the real
    delta).  NEVER auto-resolves a conflict (aborts instead); NEVER force-pushes.
    """
    parent = Path(target or os.getcwd()).resolve()
    cls = _load_classification()
    derived = _derived(cls, spice, agent, agent)
    branch = branch or derived["branch"]
    child_path = (Path(child).resolve() if child
                  else parent / derived["child"])

    # 1. discover -----------------------------------------------------------
    _log("discover")
    probe = _git(["rev-parse", "--git-dir"], repo=parent, capture=True, quiet=True)
    if probe.returncode != 0:
        _die(f"{parent} is not a git repository")
    if not (child_path / ".git").exists():
        _die(f"child checkout not found: {child_path}")

    current_branch = _git(["rev-parse", "--abbrev-ref", "HEAD"],
                          repo=parent, capture=True, quiet=True).stdout.strip()
    _info(f"parent    : {parent} (branch {current_branch})")
    _info(f"child     : {child_path} (branch {branch})")
    if not dry_run:
        status = _git(["status", "--porcelain"], repo=parent,
                      capture=True, quiet=True).stdout
        if status.strip():
            _die("parent working tree is not clean")

    # Fetch even under --dry-run: it only updates the transient FETCH_HEAD ref,
    # and the classification preview must reflect the real delta.
    _git(["fetch", str(child_path), branch], repo=parent, check=True)
    merge_ref = "FETCH_HEAD"
    merge_rev = _git(["rev-parse", "FETCH_HEAD"], repo=parent,
                     capture=True, quiet=True).stdout.strip()
    _info(f"merge ref : {merge_ref} ({merge_rev})")

    # 2. classify — the delta must be bounded to the inner trees ------------
    _log("classify")
    changed = [ln.strip() for ln in _git(
        ["diff", "--name-only", "HEAD...FETCH_HEAD"], repo=parent,
        capture=True, quiet=True).stdout.splitlines() if ln.strip()]
    if not changed:
        _die(f"no changes between HEAD and {merge_ref}")

    allow = cls.get("delta", {}).get("allowGlobs", [])
    scaffolding = cls.get("delta", {}).get("scaffolding", [])
    bounded = True
    for path in changed:
        if any(_matches(path, pat) for pat in allow):
            continue
        if any(_matches(path, pat) for pat in scaffolding):
            _info(f"scaffolding present (will not merge): {path}")
            bounded = False
        else:
            print(f"   out-of-bounds: {path}", file=sys.stderr)
            bounded = False
    if not bounded:
        _die("delta is not bounded to the inner trees (ADR 0007 D4); aborting")

    _info("changed files:")
    for path in changed:
        print(f"     {path}")

    # 3. plan [gate] --------------------------------------------------------
    _log("plan")
    _info(f"merge {merge_ref} into {current_branch} (review-state, --no-commit --no-ff)")
    _gate("approve the plan (bounded inner delta above) before merging?",
          dry_run=dry_run, assume_yes=yes)

    # 4. merge (review-state) ----------------------------------------------
    _log("merge")
    result = _git(["merge", "--no-commit", "--no-ff", merge_ref],
                  repo=parent, dry_run=dry_run)
    if not dry_run and result.returncode != 0:
        _info("conflict detected — aborting (never auto-resolving, ADR 0007 D4)")
        _git(["merge", "--abort"], repo=parent)
        _die("merge aborted; rebase the child on latest dev and retry")

    # 5. host review [gate] ------------------------------------------------
    _log("host review")
    if not dry_run:
        _git(["status"], repo=parent)
        _git(["diff", "--cached"], repo=parent)
    _gate("review the ACTUAL staged code above; commit the merge?",
          dry_run=dry_run, assume_yes=yes)

    # 6. commit -------------------------------------------------------------
    _log("commit")
    _git(["commit", "--no-edit"], repo=parent, dry_run=dry_run, check=True)
    merge_commit = None
    if not dry_run:
        merge_commit = _git(["rev-parse", "HEAD"], repo=parent,
                            capture=True, quiet=True).stdout.strip()
        _info(f"merge commit: {merge_commit}")

    # 7. separate promotion (layout-derived targets) -----------------------
    _log("promotion (separate phase)")
    if promote:
        if dry_run:
            targets = changed
        else:
            out = _git(["diff", "--name-only", "HEAD~1", "HEAD"], repo=parent,
                       capture=True, quiet=True).stdout
            targets = [ln for ln in out.splitlines() if _is_inner(ln)]
        _info(f"deriving propagation targets from the layout map in {CLASSIFY_PATH}")
        for path in targets:
            outer = _promote_path(path, cls)
            if outer:
                _info(f"promote: {path} -> {outer}")
        _info("promotion is applied by the host (image rebuild) — this task only derives targets")
    else:
        _info("skipped (pass --promote to derive outer targets; never a push)")

    # 8. verify -------------------------------------------------------------
    _log("verify")
    if dry_run:
        _info("[dry-run] nix flake check --keep-going")
    else:
        _info("run on the host: nix flake check --keep-going")

    # 9. report / rollback --------------------------------------------------
    _log("report / rollback")
    _info(f"rollback (before commit): git -C {parent} merge --abort")
    _info(f"rollback (after commit) : git -C {parent} revert -m 1 "
          f"{merge_commit or '<merge-commit>'}")
    _info("never force-push; promotion to the outer image is a deliberate host action")


@task
def classify(
    c: Context,
    spice: str = DEFAULT_SPICE,
    agent: str = DEFAULT_AGENT,
    user: str = "",
):
    """Print the merged classification map and layout-derived targets (read-only)."""
    user = user or agent
    cls = _load_classification()
    print(json.dumps(cls, indent=2, sort_keys=True))
    _log("derived layout")
    for key, value in _derived(cls, spice, agent, user).items():
        print(f"   {key:16} {value}")


@task
def selfcheck(
    c: Context,
    spice: str = DEFAULT_SPICE,
    agent: str = DEFAULT_AGENT,
    user: str = "",
):
    """Validate classify.json and the derived paths (no git, no writes).

    Exits 1 on any problem; used by ``make harness-selfcheck``.
    """
    user = user or agent
    cls = _load_classification()
    inner_platform, outer_platform = _platforms(cls)
    allow = cls.get("delta", {}).get("allowGlobs", [])
    scaffolding = cls.get("delta", {}).get("scaffolding", [])
    problems: list[str] = []

    if not allow:
        problems.append("delta.allowGlobs is empty")
    if not scaffolding:
        problems.append("delta.scaffolding is empty")

    probes = (
        f"systems/{inner_platform}/{spice}-{agent}_inner/default.nix",
        f"homes/{inner_platform}/{user}@{spice}-{agent}_inner/default.nix",
    )
    for path in probes:
        if not any(_matches(path, pat) for pat in allow):
            problems.append(f"no delta.allowGlobs pattern matches: {path}")

    for path in ("flake.nix", "flake.lock", "lib/inherit/x.nix"):
        if any(_matches(path, pat) for pat in allow):
            problems.append(f"scaffolding is allowed by delta.allowGlobs: {path}")
        if not any(_matches(path, pat) for pat in scaffolding):
            problems.append(f"scaffolding not covered by delta.scaffolding: {path}")

    promotions = (
        (probes[0], f"systems/{outer_platform}/{spice}-{agent}/default.nix"),
        (probes[1], f"homes/{inner_platform}/{user}@{spice}-{agent}/default.nix"),
    )
    for path, expected in promotions:
        got = _promote_path(path, cls)
        if got != expected:
            problems.append(f"promotion mismatch: {path} -> {got} (expected {expected})")

    if problems:
        for problem in problems:
            print(f"FAIL: {problem}", file=sys.stderr)
        raise SystemExit(1)

    print("OK: classification map and derived paths are consistent.")
    for key, value in _derived(cls, spice, agent, user).items():
        print(f"   {key:16} {value}")
