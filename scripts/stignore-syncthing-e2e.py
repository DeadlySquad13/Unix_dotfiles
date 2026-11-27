#!/usr/bin/env python3
"""Compare generated ``.stignore`` rules with Syncthing's live ignore state.

Why this exists
---------------
The activation writer (``stignore-merge.py``) appends patterns to
``<folder>/.stignore``, and the Syncthing daemon parses that file into an
internal, case-folded pattern list exposed by ``GET /rest/db/ignores``.
Nothing in the repository proved that the *daemon* sees the same rules the
writer wrote. This check closes that loop end to end:

* every non-comment ``.stignore`` line must appear in the API ``ignore`` list;
* every pattern must expand to the forms Syncthing derives from it;
* every root-anchored pattern that resolves through a symlinked project dir
  must also cover its *real* location (Syncthing syncs symlinks but never
  follows them, so an alias-only rule ignores nothing).

It is strictly read-only: only ``GET`` requests are issued, through ``curl``.

Offline mode
------------
``--payload-file`` bypasses config discovery and the network entirely. The
file may be a recorded ``/rest/db/ignores`` object or
``{"ignores": {...}, "folders": [...]}``. This is what the unit tests and the
Makefile demo use; the live mode is meant for ``@creamsoda`` and ``@salt``.

Run the unit tests with::

    python3 scripts/test_stignore_syncthing_e2e.py
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

PROG = "stignore-syncthing-e2e"
DEFAULT_FOLDER_ID = "xtnmf-9ntus"

EXIT_OK = 0
EXIT_MISMATCH = 1
EXIT_USAGE = 2


# ---------------------------------------------------------------------------
# Alias expansion (duplicated on purpose)
# ---------------------------------------------------------------------------
def expand_alias_patterns(
    patterns: list[str], projects_root: str
) -> list[str]:
    """Return patterns plus real-location variants for symlinked dirs.

    ``projects_root`` is the Syncthing folder root. For every pattern that
    starts with ``/``, the parent of the referenced path is resolved with
    ``realpath``; if that lands elsewhere inside the root, the real
    root-anchored variant is appended right after the logical pattern. The
    entry itself is never resolved (it is usually a store symlink that must
    remain ignored as a link). Patterns whose real location escapes the root
    are skipped. The result keeps first occurrence order and is idempotent.
    """
    # Keep in sync with scripts/stignore-merge.py::expand_alias_patterns.
    # No runtime import: the activation writer is a standalone store file.
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


def real_variant(pattern: str, projects_root: str) -> str | None:
    """Return the real-location variant of ``pattern``, or ``None``."""
    for candidate in expand_alias_patterns([pattern], projects_root):
        if candidate != pattern:
            return candidate
    return None


def _has_symlink_ancestor(pattern: str, projects_root: str) -> bool:
    """True when a directory above the entry is a symlink on this host."""
    if not pattern.startswith("/"):
        return False
    root = os.path.realpath(projects_root)
    parts = pattern.lstrip("/").split("/")
    current = root
    for part in parts[:-1]:
        current = os.path.join(current, part)
        if os.path.islink(current):
            return True
    return False


# ---------------------------------------------------------------------------
# Pure comparison
# ---------------------------------------------------------------------------
def load_stignore(path: str | os.PathLike[str]) -> list[str]:
    """Read ``.stignore`` lines, dropping blanks and ``//`` comments."""
    text = Path(path).read_text(encoding="utf-8")
    patterns: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        patterns.append(stripped)
    return patterns


def expected_expanded(pattern: str) -> list[str]:
    """Return the expanded forms Syncthing derives from ``pattern``.

    Syncthing case-folds every pattern and prefixes ``(?i)``. Root-anchored
    patterns keep their anchor; unanchored patterns match at any depth, which
    adds the leading ``**/`` variants. A directory match also adds ``/**``.
    """
    lowered = pattern.lower()
    if lowered.startswith("/"):
        return [
            f"(?i){lowered}",
            f"(?i){lowered}/**",
        ]
    return [
        f"(?i){lowered}",
        f"(?i)**/{lowered}",
        f"(?i){lowered}/**",
        f"(?i)**/{lowered}/**",
    ]


class Report:
    """Comparison result; ``ok`` is false when any error was recorded."""

    def __init__(self) -> None:
        self.ok = True
        self.errors: list[dict] = []
        self.warnings: list[dict] = []
        self.folder: dict = {}
        self.counts: dict = {}

    def error(
        self, code: str, message: str, pattern: str | None = None
    ) -> None:
        entry = {"code": code, "message": message}
        if pattern is not None:
            entry["pattern"] = pattern
        self.errors.append(entry)
        self.ok = False

    def warn(
        self, code: str, message: str, pattern: str | None = None
    ) -> None:
        entry = {"code": code, "message": message}
        if pattern is not None:
            entry["pattern"] = pattern
        self.warnings.append(entry)

    def to_dict(self) -> dict:
        return {
            "ok": self.ok,
            "errors": self.errors,
            "warnings": self.warnings,
            "folder": self.folder,
            "counts": self.counts,
        }


def compare(
    patterns: list[str],
    api_ignore: list[str],
    api_expanded: list[str],
    projects_root: str,
    *,
    strict: bool = False,
) -> Report:
    """Compare the file patterns with the daemon's parsed ignore state."""
    report = Report()
    api_ignore_set = set(api_ignore)
    api_expanded_set = set(api_expanded)
    file_set = set(patterns)

    # Rule 1: the file and the daemon's raw ignore list agree.
    for pattern in patterns:
        if pattern not in api_ignore_set:
            report.error(
                "MISSING_FROM_API",
                f"{pattern!r} is in .stignore but not in the daemon's "
                "ignore list",
                pattern,
            )
    seen_extra: set[str] = set()
    for entry in api_ignore:
        if entry in file_set or entry in seen_extra:
            continue
        seen_extra.add(entry)
        message = (
            f"{entry!r} is in the daemon's ignore list but not in "
            ".stignore"
        )
        if strict:
            report.error("EXTRA_IN_API", message, entry)
        else:
            report.warn("EXTRA_IN_API", message, entry)

    # Rule 2: every pattern has its expanded forms.
    for pattern in patterns:
        for form in expected_expanded(pattern):
            if form not in api_expanded_set:
                report.error(
                    "MISSING_EXPANDED",
                    f"expected expanded form {form!r} for pattern "
                    f"{pattern!r}",
                    pattern,
                )

    # Rule 3: alias coverage. The real location must be ignored too.
    for pattern in patterns:
        if not pattern.startswith("/"):
            continue
        real = real_variant(pattern, projects_root)
        if real is None:
            continue
        missing_in: list[str] = []
        if real not in api_ignore_set:
            missing_in.append("ignore")
        if any(
            form not in api_expanded_set
            for form in expected_expanded(real)
        ):
            missing_in.append("expanded")
        if missing_in:
            report.error(
                "MISSING_REAL_VARIANT",
                f"logical {pattern!r} resolves to real path {real!r}; "
                f"missing from API {', '.join(missing_in)}",
                pattern,
            )

    # Rule 4: a symlink ancestor proves the boundary must be expanded, even
    # when the real location escapes the synced root.
    for pattern in patterns:
        if not pattern.startswith("/"):
            continue
        if not _has_symlink_ancestor(pattern, projects_root):
            continue
        if real_variant(pattern, projects_root) is None:
            report.error(
                "MISSING_REAL_VARIANT",
                f"{pattern!r} passes through a symlink but no real "
                "variant inside the projects root could be derived; "
                "the ignore boundary is incomplete",
                pattern,
            )

    report.counts = {
        "file_patterns": len(patterns),
        "api_ignore": len(api_ignore),
        "api_expanded": len(api_expanded),
        "errors": len(report.errors),
        "warnings": len(report.warnings),
    }
    return report


# ---------------------------------------------------------------------------
# Payload + config handling
# ---------------------------------------------------------------------------
def load_payload(path: str | os.PathLike[str]) -> dict:
    """Load a recorded payload in either supported shape."""
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("payload must be a JSON object")
    if "ignores" in data:
        ignores = data.get("ignores") or {}
        folders = data.get("folders") or []
    else:
        ignores = data
        folders = []
    if not isinstance(ignores, dict):
        raise ValueError("payload 'ignores' must be an object")
    if not isinstance(folders, list):
        raise ValueError("payload 'folders' must be a list")
    return {"ignores": ignores, "folders": folders}


def folder_path_from(folders: list, folder_id: str) -> str | None:
    """Return the folder path for ``folder_id`` when the API listed it."""
    for folder in folders:
        if isinstance(folder, dict) and folder.get("id") == folder_id:
            path = folder.get("path")
            if isinstance(path, str) and path:
                return path
    return None


def _config_candidates() -> list[str]:
    home = os.path.expanduser("~")
    if sys.platform == "darwin":
        return [
            os.path.join(
                home,
                "Library",
                "Application Support",
                "Syncthing",
                "config.xml",
            )
        ]
    xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
        home, ".config"
    )
    candidates = [
        os.path.join(xdg, "syncthing", "config.xml"),
        os.path.join(home, ".config", "syncthing", "config.xml"),
        os.path.join(home, ".local", "state", "syncthing", "config.xml"),
        os.path.join(home, ".local", "share", "syncthing", "config.xml"),
    ]
    unique: list[str] = []
    for candidate in candidates:
        if candidate not in unique:
            unique.append(candidate)
    return unique


def _parse_paths_output(text: str) -> str | None:
    """Extract the config path from ``syncthing --paths`` output.

    Both ``Configuration file: /path`` and a label followed by the path on the
    next line are accepted.
    """
    lines = text.splitlines()
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.lower().startswith("configuration file:"):
            continue
        remainder = stripped.split(":", 1)[1].strip()
        if remainder:
            return remainder
        for following in lines[index + 1:]:
            candidate = following.strip()
            if candidate:
                return candidate
    return None


def _config_from_syncthing_paths() -> str | None:
    binary = shutil.which("syncthing")
    if binary is None:
        return None
    try:
        completed = subprocess.run(
            [binary, "--paths"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return _parse_paths_output(completed.stdout)


def find_config_xml() -> str | None:
    """Locate ``config.xml`` per host, then fall back to ``--paths``."""
    for candidate in _config_candidates():
        if os.path.isfile(candidate):
            return candidate
    from_paths = _config_from_syncthing_paths()
    if from_paths and os.path.isfile(from_paths):
        return from_paths
    return None


def parse_config(path: str | os.PathLike[str]) -> dict:
    """Parse the GUI API key, address, and TLS flag from ``config.xml``."""
    root = ET.parse(path).getroot()
    gui = root.find("gui")
    if gui is None:
        raise RuntimeError(f"{path}: no <gui> element")
    address = (gui.get("address") or "127.0.0.1:8384").strip()
    tls = (gui.get("tls") or "").strip().lower() == "true"
    return {
        "api_key": (gui.get("apikey") or "").strip(),
        "address": address,
        "tls": tls,
    }


def _endpoint(config: dict) -> dict:
    """Turn a GUI address into a curl target (TCP base URL or unix socket)."""
    address = config["address"].strip()
    if address.startswith("unix://"):
        socket_path = address[len("unix://"):]
        if not socket_path.startswith("/"):
            socket_path = "/" + socket_path
        return {"base": None, "socket": socket_path, "tls": False}

    if not address:
        address = "127.0.0.1:8384"
    if address.startswith("0.0.0.0"):
        address = "127.0.0.1" + address[len("0.0.0.0"):]
    elif address.startswith("[::]"):
        address = "127.0.0.1" + address[len("[::]"):]
    if ":" not in address:
        address = address + ":8384"
    scheme = "https" if config["tls"] else "http"
    return {
        "base": f"{scheme}://{address}",
        "socket": None,
        "tls": config["tls"],
    }


def _curl_get(endpoint: dict, path: str, api_key: str) -> object:
    """Issue a single read-only GET through curl and parse JSON."""
    command = ["curl", "-sS", "--fail"]
    if endpoint["tls"]:
        command.append("-k")
    if endpoint["socket"]:
        command += ["--unix-socket", endpoint["socket"]]
        url = "http://localhost" + path
    else:
        url = endpoint["base"] + path
    command += ["-H", f"X-API-Key: {api_key}", url]

    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode != 0:
        detail = completed.stderr.strip()
        raise RuntimeError(detail or f"curl exited {completed.returncode}")
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid JSON from {path}: {exc}") from exc


def fetch_live(
    folder_id: str, config_path: str, *, verbose: bool = False
) -> dict:
    """GET the folder list and the parsed ignore state from the daemon."""
    config = parse_config(config_path)
    if not config["api_key"]:
        raise RuntimeError(f"{config_path}: no GUI API key configured")
    endpoint = _endpoint(config)
    if verbose:
        target = endpoint["socket"] or endpoint["base"]
        print(f"{PROG}: config {config_path} -> {target}", file=sys.stderr)

    folders = _curl_get(endpoint, "/rest/config/folders", config["api_key"])
    if not isinstance(folders, list):
        raise RuntimeError("/rest/config/folders did not return a list")
    if not any(
        isinstance(folder, dict) and folder.get("id") == folder_id
        for folder in folders
    ):
        raise RuntimeError(f"folder {folder_id!r} is not configured")

    query = urllib.parse.urlencode({"folder": folder_id})
    ignores = _curl_get(
        endpoint,
        "/rest/db/ignores?" + query,
        config["api_key"],
    )
    if not isinstance(ignores, dict):
        raise RuntimeError("/rest/db/ignores did not return an object")
    return {"ignores": ignores, "folders": folders, "config": config}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog=PROG,
        description=(
            "Compare generated .stignore rules with Syncthing's live "
            "/rest/db/ignores response (GET only)."
        ),
    )
    parser.add_argument(
        "--folder-id", default=DEFAULT_FOLDER_ID, help="Syncthing folder id."
    )
    parser.add_argument(
        "--stignore",
        default=None,
        metavar="PATH",
        help="Path of .stignore (default: <folder path>/.stignore).",
    )
    parser.add_argument(
        "--projects-root",
        default=None,
        metavar="PATH",
        help="Synced projects root (default: folder path from the API).",
    )
    parser.add_argument(
        "--config-xml",
        default=None,
        metavar="PATH",
        help="Syncthing config.xml (default: auto-detect per host).",
    )
    parser.add_argument(
        "--payload-file",
        default=None,
        metavar="PATH",
        help="Offline mode: recorded ignores payload; no config or network.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat extra patterns in the API as errors.",
    )
    parser.add_argument(
        "--json", action="store_true", help="Print a machine-readable report."
    )
    parser.add_argument(
        "--require-live",
        action="store_true",
        help="Missing config/daemon is an error (default: SKIP, exit 0).",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Print connection details."
    )
    return parser.parse_args(argv)


def _fail(message: str, as_json: bool) -> int:
    if as_json:
        print(json.dumps({"ok": False, "error": message}))
    else:
        print(f"{PROG}: ERROR {message}", file=sys.stderr)
    return EXIT_USAGE


def _skip(reason: str, require_live: bool, as_json: bool) -> int:
    if require_live:
        return _fail(reason, as_json)
    if as_json:
        print(json.dumps({"ok": True, "skip": True, "reason": reason}))
    else:
        print(f"SKIP: {reason}")
    return EXIT_OK


def _format_entry(level: str, entry: dict) -> str:
    text = f"{level} {entry['code']}: {entry['message']}"
    if entry.get("pattern") is not None:
        text += f" (pattern {entry['pattern']!r})"
    return text


def _print_human(report: Report) -> None:
    for warning in report.warnings:
        print(_format_entry("WARNING", warning))
    for error in report.errors:
        print(_format_entry("ERROR", error))
    folder = report.folder
    print(f"folder {folder.get('id', '?')}: {folder.get('path', '?')}")
    counts = report.counts
    print(
        "patterns={file_patterns} api_ignore={api_ignore} "
        "api_expanded={api_expanded} errors={errors} "
        "warnings={warnings}".format(**counts)
    )
    print("PASS" if report.ok else "FAIL")


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)

    if args.payload_file:
        try:
            payload = load_payload(args.payload_file)
        except (OSError, ValueError) as exc:
            return _fail(f"cannot load payload: {exc}", args.json)
    else:
        config_path = args.config_xml or find_config_xml()
        if config_path is None:
            return _skip(
                "no Syncthing config.xml found",
                args.require_live,
                args.json,
            )
        try:
            payload = fetch_live(
                args.folder_id, config_path, verbose=args.verbose
            )
        except Exception as exc:  # noqa: BLE001 - any live failure is a SKIP
            return _skip(
                f"Syncthing daemon unreachable: {exc}",
                args.require_live,
                args.json,
            )

    ignores = payload.get("ignores") or {}
    folders = payload.get("folders") or []
    folder_path = folder_path_from(folders, args.folder_id)

    stignore_path = args.stignore or (
        os.path.join(folder_path, ".stignore") if folder_path else None
    )
    projects_root = args.projects_root or folder_path

    if stignore_path is None:
        return _fail(
            "cannot determine .stignore path; pass --stignore", args.json
        )
    if projects_root is None:
        return _fail(
            "cannot determine projects root; pass --projects-root",
            args.json,
        )

    try:
        patterns = load_stignore(stignore_path)
    except OSError as exc:
        return _fail(f"cannot read {stignore_path}: {exc}", args.json)

    report = compare(
        patterns,
        list(ignores.get("ignore") or []),
        list(ignores.get("expanded") or []),
        projects_root,
        strict=args.strict,
    )
    report.folder = {
        "id": args.folder_id,
        "path": folder_path or projects_root,
    }

    if args.json:
        print(json.dumps(report.to_dict(), indent=2, sort_keys=True))
    else:
        if args.verbose:
            print(f"{PROG}: .stignore {stignore_path}", file=sys.stderr)
            print(
                f"{PROG}: projects root {projects_root}", file=sys.stderr
            )
        _print_human(report)

    return EXIT_OK if report.ok else EXIT_MISMATCH


if __name__ == "__main__":
    sys.exit(main())
