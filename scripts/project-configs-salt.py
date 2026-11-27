#!/usr/bin/env python3
"""Host-local project config generator for the salt host.

RFC: docs/rfc/adding-nix-generated-files-into-container/README.md
Plan: docs/rfc/adding-nix-generated-files-into-container/plan.md

The generator is deliberately stdlib-only so it can run from a Home Manager
activation script without a project environment.

Modes
-----
* default            materialise the generation root, prune, write the manifest
* ``--check``        validate the manifest and the real generation-root files
* ``--dry-run``      print the plan without touching the filesystem
* ``--write-links``  replace the ignored project paths with salt-local links
* ``--discover``     emit Tier 2 ignore patterns for absolute symlinks; the
  walk is physical, so it reports real paths (never alias paths)
* ``--discover-compare``  compare Tier 2 discovery with the Tier 1 model

Safety
------
* The generation root is outside the synced tree; it is materialised from
  dereferenced sources (no absolute store symlinks, no ``/Users/...``).
* Project paths are only replaced after the *effective* Syncthing ignore
  boundary has been verified. The check is an explicit function
  (:func:`check_ignore_boundary`) so it can be unit-tested in isolation.
* A missing symlink target or a symlink inside the generation root fails closed.
* Covered project paths are replaced only inside the model: a symlink is
  repointed, a regular file is replaced, and a real directory is replaced only
  when its content hash equals the freshly generated tree (otherwise
  ``PROJECT_CONFIG_STALE``). ``--force-replace`` overrides a differing
  directory. Nothing outside the covered set is touched.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import shutil
import socket
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

SCHEMA_VERSION = 1
GENERATOR_ID = "unix-dotfiles/project-configs@1"

PROJECT_CONFIG_ROOT_MISSING = "PROJECT_CONFIG_ROOT_MISSING"
PROJECT_CONFIG_MANIFEST_INVALID = "PROJECT_CONFIG_MANIFEST_INVALID"
PROJECT_CONFIG_LINK_MISSING = "PROJECT_CONFIG_LINK_MISSING"
PROJECT_CONFIG_STALE = "PROJECT_CONFIG_STALE"
PROJECT_CONFIG_IGNORE_MISSING = "PROJECT_CONFIG_IGNORE_MISSING"

#: Directory names never copied into the generation root.
SKIP_COPY_DIRS = frozenset({".git", ".direnv", "nix-shell-env"})

#: Top-level synced folders that are separate Syncthing roots or scratchpads.
SKIP_TOP_LEVEL = frozenset({".artifact", ".artifacts--processed", "ai-"})

#: Absolute symlink prefixes that are valid on every host.
HOST_NEUTRAL_PREFIXES = ("/shared/", "/mnt/")

#: Host build state that must not sync but is never part of the generated model.
HOST_STATE_SEGMENTS = (".direnv", "nix-shell-env")

#: Guard against symlink cycles while dereferencing directory trees.
MAX_TREE_DEPTH = 64


class ConfigError(Exception):
    """A fail-closed generator error with a stable error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def warn(message: str) -> None:
    print(f"WARNING: {message}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------
def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_tree(root: str) -> str:
    """Deterministic hash of a directory tree: sorted ``relpath\\0sha256``."""
    lines: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames.sort()
        filenames.sort()
        for name in filenames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                raise ConfigError(
                    PROJECT_CONFIG_MANIFEST_INVALID,
                    f"generation root contains a symlink: {path}",
                )
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            lines.append(f"{rel}\0{sha256_file(path)}\n")
    return hashlib.sha256("".join(lines).encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------
def _norm_pattern(pattern: str) -> str:
    return pattern.strip().lstrip("/").rstrip("/")


def sanitize_relative(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"{label}: expected a non-empty string")
    if posixpath.isabs(value):
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"{label}: must be relative: {value}")
    normalised = posixpath.normpath(value)
    if normalised in (".", "") or normalised == ".." or normalised.startswith("../"):
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"{label}: unsafe path: {value}")
    return normalised


def _join_inside(root: str, relative: str, label: str) -> str:
    root = os.path.normpath(root)
    candidate = os.path.normpath(os.path.join(root, relative))
    if os.path.commonpath([root, candidate]) != root:
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"{label}: escapes {root}: {relative}")
    return candidate


def _is_within(child: str, parent: str) -> bool:
    child = os.path.normpath(child)
    parent = os.path.normpath(parent)
    return child == parent or child.startswith(parent.rstrip(os.sep) + os.sep)


def expand_alias_patterns(
    patterns: list[str], projects_root: str
) -> list[str]:
    """Return patterns plus real-location variants for symlinked dirs.

    Syncthing syncs symlinks but never follows them: it indexes the real tree
    under the synced folder, so an ignore pattern anchored on an alias path
    (``/--professional/Rutube__/AutoHub/_scripts``) never matches the real
    ``auto-hub`` tree. For every root-anchored pattern, resolve the *parent*
    with ``realpath`` and append the real variant when it stays inside the
    root. The entry itself is never resolved: it is usually a store symlink
    that must remain ignored as a link, not become a ``/nix/store/...``
    pattern. Escaping variants are skipped; order is preserved and the result
    is deduplicated and idempotent.
    """
    # Keep in sync with the other copy in scripts/ (no runtime import: the
    # activation writer is a standalone store file).
    root = os.path.realpath(projects_root)
    expanded: list[str] = []
    seen: set[str] = set()

    def add(pattern: str) -> None:
        if pattern in seen:
            return
        seen.add(pattern)
        expanded.append(pattern)

    for pattern in patterns:
        add(pattern)
        if not pattern.startswith("/"):
            continue
        abs_path = os.path.normpath(
            os.path.join(root, pattern.lstrip("/"))
        )
        parent_real = os.path.realpath(os.path.dirname(abs_path))
        real_path = os.path.join(parent_real, os.path.basename(abs_path))
        if real_path == abs_path:
            continue
        try:
            inside = os.path.commonpath([root, real_path]) == root
        except ValueError:
            inside = False
        if not inside:
            continue
        relative = os.path.relpath(real_path, root).replace(os.sep, "/")
        add("/" + relative)

    return expanded


def _atomic_write_text(path: str, text: str, mode: int = 0o644) -> None:
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".tmp-", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def _remove(path: str) -> None:
    if os.path.islink(path) or os.path.isfile(path):
        os.unlink(path)
    elif os.path.isdir(path):
        shutil.rmtree(path)


# ---------------------------------------------------------------------------
# Ignore-boundary gate (Phase 3)
# ---------------------------------------------------------------------------
def check_ignore_boundary(expected: Iterable[str], effective: Iterable[str]) -> list[str]:
    """Return the expected patterns that the effective list does not cover.

    Exact (root-anchored, normalised) comparison: derived patterns are literal
    paths, so a broader glob is not accepted as proof that the generated path is
    ignored. An empty result means the boundary is verified.
    """
    effective_set = {_norm_pattern(pattern) for pattern in effective if pattern.strip()}
    missing = sorted(
        {_norm_pattern(pattern) for pattern in expected if _norm_pattern(pattern)} - effective_set
    )
    return missing


def expand_expected_patterns(
    patterns: Iterable[str], projects_root: str | None
) -> list[str]:
    """Expand logical ignore patterns with their real symlink locations.

    Falls back to the unexpanded list with a diagnostic when the root is
    missing or does not exist, so a host without the synced tree still runs
    the gate instead of crashing.
    """
    pattern_list = list(patterns)
    if not projects_root:
        warn(
            "projects_root is unavailable; Syncthing ignore boundary uses "
            "logical patterns only (symlinked project dirs are not covered)"
        )
        return pattern_list
    if not os.path.isdir(projects_root):
        warn(
            f"projects_root does not exist: {projects_root}; Syncthing "
            "ignore boundary uses logical patterns only (symlinked project "
            "dirs are not covered)"
        )
        return pattern_list
    return expand_alias_patterns(pattern_list, projects_root)


def read_effective_patterns(
    *,
    effective_file: str | None,
    effective_cmd: str | None,
) -> list[str]:
    if effective_file is not None:
        try:
            text = Path(effective_file).read_text(encoding="utf-8")
        except OSError as exc:
            raise ConfigError(
                PROJECT_CONFIG_IGNORE_MISSING,
                f"cannot read effective ignore file {effective_file}: {exc}",
            ) from exc
    elif effective_cmd is not None:
        completed = subprocess.run(
            effective_cmd,
            shell=True,
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode != 0:
            raise ConfigError(
                PROJECT_CONFIG_IGNORE_MISSING,
                f"effective ignore command failed ({completed.returncode}): "
                f"{completed.stderr.strip() or effective_cmd}",
            )
        text = completed.stdout
    else:
        raise ConfigError(
            PROJECT_CONFIG_IGNORE_MISSING,
            "no effective ignore source configured; set --effective-ignore-file "
            "or --effective-ignore-cmd (fail closed)",
        )

    patterns: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        patterns.append(stripped)
    return patterns


def verify_ignore_boundary(
    expected: Iterable[str],
    *,
    effective_file: str | None,
    effective_cmd: str | None,
) -> list[str]:
    """Fail closed unless every expected pattern is in the effective list."""
    effective = read_effective_patterns(
        effective_file=effective_file,
        effective_cmd=effective_cmd,
    )
    missing = check_ignore_boundary(expected, effective)
    if missing:
        raise ConfigError(
            PROJECT_CONFIG_IGNORE_MISSING,
            "effective Syncthing ignore list is missing generated paths: "
            + ", ".join(missing),
        )
    return effective


# ---------------------------------------------------------------------------
# Materialisation
# ---------------------------------------------------------------------------
def _source_path(entry: dict[str, Any], projects_root: str) -> str:
    source = entry.get("source")
    if not isinstance(source, str) or not source:
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"entry {entry.get('logical')!r}: source is required for kind {entry.get('kind')!r}",
        )
    if os.path.isabs(source):
        return os.path.normpath(source)
    # Plan payload form: paths are relative to the synced root's parent and
    # start with the root basename (``Projects/...``). Absolute sources are the
    # native form produced by the Nix module.
    root_name = os.path.basename(os.path.normpath(projects_root))
    if source == root_name or source.startswith(root_name + "/"):
        return os.path.normpath(os.path.join(os.path.dirname(projects_root), source))
    return os.path.normpath(os.path.join(projects_root, source))


def _require_source(source: str) -> None:
    if not os.path.lexists(source):
        raise ConfigError(PROJECT_CONFIG_LINK_MISSING, f"source is missing: {source}")
    if os.path.islink(source) and not os.path.exists(source):
        raise ConfigError(
            PROJECT_CONFIG_LINK_MISSING,
            f"source symlink is dangling: {source} -> {os.readlink(source)}",
        )


def _copy_file(source: str, destination: str) -> None:
    _require_source(source)
    if not os.path.isfile(source):
        raise ConfigError(PROJECT_CONFIG_LINK_MISSING, f"source is not a regular file: {source}")
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".tmp-", dir=os.path.dirname(destination))
    os.close(fd)
    try:
        shutil.copyfile(source, tmp)  # follows symlinks (dereference)
        os.chmod(tmp, 0o644)
        os.replace(tmp, destination)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def _copy_tree_into(
    source: str,
    destination: str,
    *,
    seen: set[tuple[int, int]],
    depth: int,
) -> None:
    if depth > MAX_TREE_DEPTH:
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"directory copy exceeded depth {MAX_TREE_DEPTH}: {source}",
        )
    try:
        stat = os.stat(source)
    except OSError as exc:
        raise ConfigError(PROJECT_CONFIG_LINK_MISSING, f"cannot stat {source}: {exc}") from exc
    identity = (stat.st_dev, stat.st_ino)
    if identity in seen:
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"symlink cycle while copying {source}",
        )
    seen.add(identity)

    os.makedirs(destination, mode=0o755, exist_ok=True)
    with os.scandir(source) as entries:
        for item in sorted(entries, key=lambda entry: entry.name):
            if item.name in SKIP_COPY_DIRS:
                continue
            path = item.path
            if item.is_symlink() and not os.path.exists(path):
                raise ConfigError(
                    PROJECT_CONFIG_LINK_MISSING,
                    f"source symlink is dangling: {path} -> {os.readlink(path)}",
                )
            if item.is_dir(follow_symlinks=True):
                _copy_tree_into(
                    path,
                    os.path.join(destination, item.name),
                    seen=seen,
                    depth=depth + 1,
                )
            elif item.is_file(follow_symlinks=True):
                target = os.path.join(destination, item.name)
                shutil.copyfile(path, target)
                os.chmod(target, 0o644)
            else:
                # Sockets, FIFOs and devices are host state, not project config.
                warn(f"skipping non-regular source entry: {path}")


def _copy_tree(source: str, destination: str) -> None:
    _require_source(source)
    if not os.path.isdir(source):
        raise ConfigError(PROJECT_CONFIG_LINK_MISSING, f"source is not a directory: {source}")
    tmp = f"{destination}.new.{os.getpid()}"
    _remove(tmp)
    try:
        _copy_tree_into(source, tmp, seen=set(), depth=0)
        backup = f"{destination}.old.{os.getpid()}"
        _remove(backup)
        if os.path.lexists(destination):
            os.replace(destination, backup)
        os.replace(tmp, destination)
        _remove(backup)
    except BaseException:
        _remove(tmp)
        raise


def materialise(payload: dict[str, Any], *, dry_run: bool) -> list[dict[str, Any]]:
    generation_root = payload["generation_root"]
    projects_root = payload["projects_root"]
    prefix = os.path.basename(os.path.normpath(projects_root))
    if not prefix or prefix in (".", "/"):
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"cannot derive a generation subdirectory from projects_root {projects_root}",
        )

    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "payload has no entries")

    planned: list[tuple[dict[str, Any], str]] = []
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"entries[{index}] is not an object")
        logical = sanitize_relative(entry.get("logical"), f"entries[{index}].logical")
        kind = entry.get("kind")
        if kind not in ("file", "dir", "text"):
            raise ConfigError(
                PROJECT_CONFIG_MANIFEST_INVALID,
                f"entries[{index}].kind must be file/dir/text: {kind!r}",
            )
        destination = _join_inside(
            os.path.join(generation_root, prefix),
            logical,
            f"entries[{index}]",
        )
        planned.append(({**entry, "logical": logical}, destination))

    if dry_run:
        for entry, destination in planned:
            print(f"materialise {entry['kind']:4s} {entry['logical']} -> {destination}")
        return []

    _ensure_generation_root(generation_root)

    manifest_entries: list[dict[str, Any]] = []
    for entry, destination in planned:
        kind = entry["kind"]
        logical = entry["logical"]
        if kind == "text":
            text = entry.get("text")
            if not isinstance(text, str):
                raise ConfigError(
                    PROJECT_CONFIG_MANIFEST_INVALID,
                    f"entry {logical!r}: text is required for kind text",
                )
            _atomic_write_text(destination, text)
            digest = sha256_file(destination)
        elif kind == "file":
            _copy_file(_source_path(entry, projects_root), destination)
            digest = sha256_file(destination)
        else:
            _copy_tree(_source_path(entry, projects_root), destination)
            digest = sha256_tree(destination)
        manifest_entries.append(
            {
                "path": posixpath.join(prefix, logical),
                "kind": kind,
                "sha256": digest,
            }
        )

    _verify_no_symlinks(os.path.join(generation_root, prefix))
    if payload.get("prune", True):
        _prune(os.path.join(generation_root, prefix), planned, prefix)
    return sorted(manifest_entries, key=lambda item: item["path"])


def _ensure_generation_root(generation_root: str) -> None:
    if not os.path.isabs(generation_root):
        raise ConfigError(
            PROJECT_CONFIG_ROOT_MISSING,
            f"generation root must be absolute: {generation_root}",
        )
    if os.path.exists(generation_root) and not os.path.isdir(generation_root):
        raise ConfigError(
            PROJECT_CONFIG_ROOT_MISSING,
            f"generation root is not a directory: {generation_root}",
        )
    try:
        os.makedirs(generation_root, mode=0o755, exist_ok=True)
    except OSError as exc:
        raise ConfigError(
            PROJECT_CONFIG_ROOT_MISSING,
            f"cannot create generation root {generation_root}: {exc}",
        ) from exc
    if not os.access(generation_root, os.W_OK):
        raise ConfigError(
            PROJECT_CONFIG_ROOT_MISSING,
            f"generation root is not writable: {generation_root}",
        )


def _verify_no_symlinks(root: str) -> None:
    if not os.path.isdir(root):
        return
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        for name in dirnames + filenames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                raise ConfigError(
                    PROJECT_CONFIG_MANIFEST_INVALID,
                    f"generation root contains a symlink: {path}",
                )


def _prune(
    prefix_root: str,
    planned: list[tuple[dict[str, Any], str]],
    prefix: str,
) -> None:
    """Remove stale generated paths, but never unrelated generation-root data."""
    if not os.path.isdir(prefix_root):
        return
    keep_files: set[str] = set()
    keep_dirs: set[str] = set()
    dir_entries: set[str] = set()
    for entry, _destination in planned:
        rel = posixpath.join(prefix, entry["logical"])
        if entry["kind"] == "dir":
            dir_entries.add(rel)
        else:
            keep_files.add(rel)
        parent = posixpath.dirname(rel)
        while parent and parent != prefix:
            keep_dirs.add(parent)
            parent = posixpath.dirname(parent)
    keep_dirs.add(prefix)

    def covered_by_dir_entry(rel: str) -> bool:
        return any(rel == entry or rel.startswith(entry + "/") for entry in dir_entries)

    for dirpath, dirnames, filenames in os.walk(prefix_root, topdown=False, followlinks=False):
        for name in filenames:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, os.path.dirname(prefix_root)).replace(os.sep, "/")
            if rel in keep_files or covered_by_dir_entry(rel):
                continue
            print(f"prune {rel}")
            _remove(path)
        for name in dirnames:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, os.path.dirname(prefix_root)).replace(os.sep, "/")
            if rel in keep_dirs or covered_by_dir_entry(rel):
                continue
            try:
                if not os.listdir(path):
                    print(f"prune {rel}")
                    os.rmdir(path)
            except OSError:
                pass


# ---------------------------------------------------------------------------
# Salt-local links
# ---------------------------------------------------------------------------
def project_link_paths(
    payload: dict[str, Any], entries: Iterable[dict[str, Any]]
) -> list[tuple[str, str, str]]:
    projects_root = payload["projects_root"]
    generation_root = payload["generation_root"]
    prefix = os.path.basename(os.path.normpath(projects_root))
    links: list[tuple[str, str, str]] = []
    for entry in entries:
        logical = sanitize_relative(entry["logical"], "logical")
        project_path = _join_inside(projects_root, logical, "project link")
        target = _join_inside(
            os.path.join(generation_root, prefix),
            logical,
            "generation link target",
        )
        links.append((logical, project_path, target))
    return links


def _entry_kind(entry: dict[str, Any]) -> str:
    """Return the manifest kind (``file``/``dir``) for a payload entry."""
    return "dir" if entry.get("kind") == "dir" else "file"


def _link_manifest_entry(plan: dict[str, Any]) -> dict[str, Any]:
    """Describe one covered path for the ``project_links`` manifest section."""
    return {
        "logical": plan["logical"],
        "kind": plan["kind"],
        "sha256": plan["sha256"],
        "path": plan["path"],
        "target": plan["target"],
    }


def plan_project_links(
    payload: dict[str, Any],
    entries: Iterable[dict[str, Any]],
    *,
    force_replace: bool = False,
) -> list[dict[str, Any]]:
    """Classify every covered project path without touching the filesystem.

    The returned ``action`` is one of ``none`` (correct symlink), ``create``,
    ``repoint``, ``replace`` (regular file or identical directory), ``stale``
    (real directory whose content differs from the freshly generated tree), or
    ``skip`` (parent directory is missing, matching the previous behaviour).
    ``stale`` is only returned when ``force_replace`` is false.
    """
    entry_list = list(entries)
    plans: list[dict[str, Any]] = []
    for (logical, project_path, target), entry in zip(
        project_link_paths(payload, entry_list), entry_list
    ):
        if not os.path.exists(target):
            raise ConfigError(
                PROJECT_CONFIG_LINK_MISSING,
                f"generation target is missing for {logical}: {target}",
            )
        kind = _entry_kind(entry)
        digest = sha256_tree(target) if kind == "dir" else sha256_file(target)

        if not os.path.isdir(os.path.dirname(project_path)):
            action = "skip"
        elif os.path.islink(project_path):
            action = "none" if os.readlink(project_path) == target else "repoint"
        elif not os.path.lexists(project_path):
            action = "create"
        elif os.path.isdir(project_path):
            if sha256_tree(project_path) == digest:
                action = "replace"
            else:
                action = "replace" if force_replace else "stale"
        elif os.path.isfile(project_path):
            action = "replace"
        else:
            raise ConfigError(
                PROJECT_CONFIG_LINK_MISSING,
                f"refusing to replace a non-symlink project path: {project_path}",
            )

        plans.append(
            {
                "logical": logical,
                "path": project_path,
                "target": target,
                "kind": kind,
                "sha256": digest,
                "action": action,
            }
        )
    return plans


def write_project_links(
    payload: dict[str, Any],
    entries: list[dict[str, Any]],
    *,
    boundary_verified: bool,
    dry_run: bool,
    force_replace: bool = False,
) -> list[dict[str, Any]]:
    """Replace ignored project paths with absolute links into the generation root.

    ``boundary_verified`` is not a hint: it must be the result of
    :func:`check_ignore_boundary` returning an empty list. This function refuses
    to write otherwise.

    Replacement is limited to the covered set (the paths described by
    :func:`project_link_paths`). A differing real directory aborts the whole run
    with ``PROJECT_CONFIG_STALE`` before anything is changed, unless
    ``force_replace`` is set. A second run is a no-op.
    """
    if not boundary_verified:
        raise ConfigError(
            PROJECT_CONFIG_IGNORE_MISSING,
            "refusing to write salt-local links without a verified ignore boundary",
        )

    plans = plan_project_links(payload, entries, force_replace=force_replace)
    stale = [plan for plan in plans if plan["action"] == "stale"]
    if stale:
        raise ConfigError(
            PROJECT_CONFIG_STALE,
            "project directory differs from the generated tree: "
            + ", ".join(plan["path"] for plan in stale)
            + " (re-run with --force-replace to replace)",
        )

    written: list[dict[str, Any]] = []
    for plan in plans:
        project_path = plan["path"]
        target = plan["target"]
        action = plan["action"]
        if action == "skip":
            warn(f"project parent directory is missing; not creating link: {project_path}")
            continue
        if action != "none":
            if dry_run:
                print(f"{action} {project_path} -> {target}")
            else:
                if action in ("replace", "repoint"):
                    _remove(project_path)
                tmp = f"{project_path}.tmp.{os.getpid()}"
                if os.path.lexists(tmp):
                    _remove(tmp)
                os.symlink(target, tmp)
                os.replace(tmp, project_path)
                if not os.path.exists(project_path):
                    raise ConfigError(
                        PROJECT_CONFIG_LINK_MISSING,
                        f"project link does not resolve: {project_path} -> {target}",
                    )
        written.append(_link_manifest_entry(plan))
    return written


# ---------------------------------------------------------------------------
# Discovery (Tier 2 drift check only)
# ---------------------------------------------------------------------------
def _absolute_host_specific(target: str) -> bool:
    return os.path.isabs(target) and not target.startswith(HOST_NEUTRAL_PREFIXES)


def is_host_state_pattern(pattern: str) -> bool:
    """True for ``.direnv``/``nix-shell-env`` paths, which are not model entries."""
    parts = pattern.strip().lstrip("/").split("/")
    return any(segment in HOST_STATE_SEGMENTS for segment in parts)


def discover_ignore_patterns(projects_root: str) -> list[str]:
    """Emit patterns for absolute symlinks under the synced projects root.

    This walks the *physical* tree (``followlinks=False``), so it reports real
    paths such as ``/auto-hub/_scripts`` and never alias paths like
    ``/--professional/Rutube__/AutoHub/_scripts``. ``--discover-compare`` and
    the manifest check compare it against the expanded Tier 1 list (logical
    pattern plus the same real variant), keeping the two sides comparable.
    Relative symlinks and internal aliases stay syncable. ``.git`` internals are
    skipped except the explicit ``info/exclude`` (and ``info``) entry, matching
    the generated model. Tier 2 is a drift check; it does not write Syncthing
    state (hot-reload of a ``#include``d file is unverified — see open questions).
    """
    root = os.path.normpath(projects_root)
    patterns: set[str] = set()

    def consider(path: str) -> None:
        if not os.path.islink(path):
            return
        target = os.readlink(path)
        if not _absolute_host_specific(target):
            return
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        patterns.add("/" + rel)

    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        relative_dir = os.path.relpath(dirpath, root)
        if relative_dir == ".":
            dirnames[:] = [name for name in dirnames if name not in SKIP_TOP_LEVEL]

        # Symlinks can be listed as either directories or files.
        for name in dirnames + filenames:
            consider(os.path.join(dirpath, name))

        kept: list[str] = []
        for name in dirnames:
            path = os.path.join(dirpath, name)
            if name == ".git" and not os.path.islink(path):
                for tail in ("info/exclude", "info"):
                    consider(os.path.join(path, tail))
                continue
            if name in SKIP_COPY_DIRS and not os.path.islink(path):
                continue
            kept.append(name)
        dirnames[:] = kept

    return sorted(patterns)


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------
def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_manifest(
    payload: dict[str, Any],
    entries: list[dict[str, Any]],
    *,
    ignore_patterns: list[str],
    ignore_boundary_verified: bool,
    project_links: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": _now(),
        "generator": GENERATOR_ID,
        "source_host": os.environ.get("PROJECT_CONFIG_SOURCE_HOST")
        or f"@{socket.gethostname()}",
        "syncthing_root": payload["syncthing_root"],
        "projects_root": payload["projects_root"],
        "generation_root": payload["generation_root"],
        "covered_paths": [entry["path"] for entry in entries],
        "entries": entries,
        "ignore_patterns": ignore_patterns,
        "ignore_boundary_verified": ignore_boundary_verified,
        "project_links": project_links,
    }


def write_manifest(path: str, manifest: dict[str, Any], *, dry_run: bool) -> None:
    text = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    if dry_run:
        print(f"manifest {path}")
        return
    _atomic_write_text(path, text)


def check_manifest(manifest_path: str, *, require_ignore: bool, payload: dict[str, Any] | None) -> None:
    try:
        manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    except OSError as exc:
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"cannot read manifest {manifest_path}: {exc}",
        ) from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"manifest is not valid JSON: {exc}",
        ) from exc

    if not isinstance(manifest, dict) or manifest.get("schema_version") != SCHEMA_VERSION:
        raise ConfigError(
            PROJECT_CONFIG_MANIFEST_INVALID,
            f"manifest schema_version must be {SCHEMA_VERSION}",
        )

    generation_root = manifest.get("generation_root")
    if not isinstance(generation_root, str) or not os.path.isdir(generation_root):
        raise ConfigError(
            PROJECT_CONFIG_ROOT_MISSING,
            f"generation root is missing: {generation_root}",
        )

    entries = manifest.get("entries")
    if not isinstance(entries, list):
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "manifest entries must be a list")

    for entry in entries:
        path = sanitize_relative(entry.get("path"), "manifest entry path")
        target = _join_inside(generation_root, path, "manifest entry")
        kind = entry.get("kind")
        if not os.path.exists(target):
            raise ConfigError(PROJECT_CONFIG_LINK_MISSING, f"manifest path is missing: {target}")
        if kind == "dir":
            actual = sha256_tree(target)
        else:
            actual = sha256_file(target)
        if actual != entry.get("sha256"):
            raise ConfigError(
                PROJECT_CONFIG_STALE,
                f"sha256 mismatch for {target}: manifest {entry.get('sha256')} != {actual}",
            )

    for link in manifest.get("project_links") or []:
        path = link.get("path")
        expected = link.get("target")
        if not isinstance(path, str) or not isinstance(expected, str):
            raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "invalid project_links entry")
        if not os.path.islink(path) or os.readlink(path) != expected:
            raise ConfigError(
                PROJECT_CONFIG_LINK_MISSING,
                f"project link is missing or wrong: {path} -> {expected}",
            )
        if not os.path.exists(path):
            raise ConfigError(
                PROJECT_CONFIG_LINK_MISSING,
                f"project link does not resolve: {path} -> {expected}",
            )

    if require_ignore:
        expected_patterns = manifest.get("ignore_patterns")
        if not isinstance(expected_patterns, list):
            raise ConfigError(
                PROJECT_CONFIG_MANIFEST_INVALID,
                "manifest has no ignore_patterns to verify",
            )
        root = manifest.get("syncthing_root") or manifest.get("projects_root")
        if not isinstance(root, str):
            raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "manifest has no synced root")
        projects_root = manifest.get("projects_root")
        if not isinstance(projects_root, str) or not projects_root:
            projects_root = root
        expected_patterns = expand_expected_patterns(
            expected_patterns, projects_root
        )
        discovered = discover_ignore_patterns(root)
        extra = sorted(
            pattern
            for pattern in set(discovered) - set(expected_patterns)
            if not is_host_state_pattern(pattern)
        )
        if extra:
            raise ConfigError(
                PROJECT_CONFIG_IGNORE_MISSING,
                "Tier 2 discovery found host-specific paths missing from Tier 1: "
                + ", ".join(extra),
            )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def load_payload(path: str) -> dict[str, Any]:
    try:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
    except OSError as exc:
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"cannot read payload {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"payload is not valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "payload must be a JSON object")
    for key in ("syncthing_root", "projects_root", "generation_root", "manifest_path"):
        if not isinstance(payload.get(key), str) or not payload[key]:
            raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, f"payload.{key} is required")
    return payload


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="project-configs-salt",
        description="Generate host-local project configs on @salt (RFC project-configs).",
    )
    parser.add_argument("--input", help="Path of the JSON payload produced by the Nix module.")
    parser.add_argument("--check", action="store_true", help="Validate the manifest and files.")
    parser.add_argument("--dry-run", action="store_true", help="Print the plan; write nothing.")
    parser.add_argument("--write-links", action="store_true", help="Replace project paths with links.")
    parser.add_argument(
        "--force-replace",
        action="store_true",
        help="Replace a differing real project directory (default: fail closed with PROJECT_CONFIG_STALE).",
    )
    parser.add_argument(
        "--require-ignore",
        action="store_true",
        help="Fail closed unless the effective Syncthing ignore boundary covers the model.",
    )
    parser.add_argument(
        "--effective-ignore-file",
        default=None,
        help="File with effective Syncthing ignore patterns (one per line).",
    )
    parser.add_argument(
        "--effective-ignore-cmd",
        default=None,
        help="Shell command printing effective Syncthing ignore patterns.",
    )
    parser.add_argument("--no-prune", action="store_true", help="Do not prune stale generation-root paths.")
    parser.add_argument(
        "--discover",
        action="store_true",
        help="Emit Tier 2 ignore patterns for absolute symlinks (drift check).",
    )
    parser.add_argument(
        "--discover-compare",
        action="store_true",
        help="Compare Tier 2 discovery with the payload Tier 1 patterns.",
    )
    parser.add_argument(
        "--projects-root",
        default=None,
        help="Override the synced projects root (discovery modes only).",
    )
    return parser


def _discover_root(args: argparse.Namespace, payload: dict[str, Any] | None) -> str:
    if args.projects_root:
        return args.projects_root
    if payload is not None:
        return payload["projects_root"]
    raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "--projects-root or --input is required")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    payload: dict[str, Any] | None = None
    if args.input:
        payload = load_payload(args.input)
        if args.no_prune:
            payload["prune"] = False

    try:
        if args.discover:
            print("\n".join(discover_ignore_patterns(_discover_root(args, payload))))
            return 0

        if args.discover_compare:
            root = _discover_root(args, payload)
            discovered = discover_ignore_patterns(root)
            expected = payload.get("ignore_patterns") if payload else []
            if not isinstance(expected, list):
                expected = []
            expected = expand_expected_patterns(expected, root)
            extra = sorted(
                pattern
                for pattern in set(discovered) - set(expected)
                if not is_host_state_pattern(pattern)
            )
            host_state = sorted(
                pattern
                for pattern in set(discovered) - set(expected)
                if is_host_state_pattern(pattern)
            )
            missing = sorted(set(expected) - set(discovered))
            for pattern in extra:
                print(f"drift (extra): {pattern}")
            for pattern in host_state:
                print(f"host-state (not modelled): {pattern}")
            for pattern in missing:
                print(f"drift (not yet generated): {pattern}")
            return 1 if extra else 0

        if args.check:
            manifest_path = payload["manifest_path"] if payload else None
            if not manifest_path:
                raise ConfigError(
                    PROJECT_CONFIG_MANIFEST_INVALID,
                    "--check requires --input (for the manifest path)",
                )
            check_manifest(manifest_path, require_ignore=args.require_ignore, payload=payload)
            drift = False
            if payload is not None and isinstance(payload.get("entries"), list):
                for plan in plan_project_links(
                    payload, payload["entries"], force_replace=args.force_replace
                ):
                    if plan["action"] in ("create", "repoint", "replace", "stale"):
                        print(f"{plan['action']} {plan['path']} -> {plan['target']}")
                        drift = True
            return 1 if drift else 0

        if payload is None:
            raise ConfigError(PROJECT_CONFIG_MANIFEST_INVALID, "--input is required")

        boundary_verified = False
        if args.write_links or args.require_ignore:
            # Fail closed before any write: the generation root is safe, but the
            # synced project tree is only touched after this succeeds.
            expected_patterns = expand_expected_patterns(
                payload.get("ignore_patterns") or [],
                payload.get("projects_root"),
            )
            verify_ignore_boundary(
                expected_patterns,
                effective_file=args.effective_ignore_file,
                effective_cmd=args.effective_ignore_cmd,
            )
            boundary_verified = True

        entries = materialise(payload, dry_run=args.dry_run)

        project_links: list[dict[str, Any]] = []
        if args.write_links:
            project_links = write_project_links(
                payload,
                payload["entries"],
                boundary_verified=boundary_verified,
                dry_run=args.dry_run,
                force_replace=args.force_replace,
            )

        if args.dry_run:
            return 0

        manifest = build_manifest(
            payload,
            entries,
            ignore_patterns=list(payload.get("ignore_patterns") or []),
            ignore_boundary_verified=boundary_verified,
            project_links=project_links,
        )
        write_manifest(payload["manifest_path"], manifest, dry_run=False)
        print(
            f"generated {len(entries)} entries under {payload['generation_root']} "
            f"({len(project_links)} project links)"
        )
        return 0
    except ConfigError as exc:
        print(f"{exc.code}: {exc.message}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
