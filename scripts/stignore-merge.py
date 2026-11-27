#!/usr/bin/env python3
"""Non-destructively merge ignore patterns into a Syncthing ``.stignore``.

Why this exists
---------------
The Home Manager Syncthing module pushes ``settings.folders.<name>`` verbatim
to ``/rest/config/folders``. Syncthing's folder config has no
``ignorePatterns`` field: ignores live in ``<folder>/.stignore`` and are
managed through ``/rest/db/ignores``. The NixOS module writes that endpoint
explicitly; the Home Manager module does not, so every declared
``ignorePatterns`` entry is silently dropped. This helper writes the file
directly for both hosts (``writeMode = "home.file"`` and ``"activation"``).

Contract
--------
* Existing lines are preserved byte-for-byte, in order (comments and blank
  lines included). Nothing is ever removed or reordered.
* Only patterns that are not already present as an exact line (``grep -Fx``
  semantics) are appended, in the order requested. A shorter line is never
  treated as covering a longer pattern (or vice versa): membership is exact.
* Appended lines reuse the newline style already present in the file (CRLF
  when the existing content contains CRLF, LF otherwise). Existing lines are
  never rewritten.
* Writes are atomic (temp file in the same directory + ``os.replace``,
  mode ``0644``); no partial file is observable.
* Idempotent: a second run appends nothing.
* A missing parent directory means the synced folder does not exist yet on a
  fresh host: print ``SKIP`` and exit ``0`` so a home-manager switch is not
  failed. This applies to ``--check`` too, which is diagnostic otherwise.

Modes
-----
* default     create/merge the file
* ``--dry-run`` print what would be appended, write nothing
* ``--check`` exit ``0`` if every requested pattern is present, ``1`` if any
  is missing; write nothing

Run the unit tests with::

    python3 scripts/test_stignore_merge.py
"""

from __future__ import annotations

import argparse
import os
import sys
import tempfile
from pathlib import Path

PROG = "stignore-merge"

EXIT_OK = 0
EXIT_MISSING = 1


def _read_existing(path: Path) -> str:
    """Return the current file text, preserving newlines, or ``""``."""
    try:
        # ``newline=""`` disables universal-newline translation so a host's
        # existing bytes are carried over untouched.
        with path.open("r", encoding="utf-8", newline="") as handle:
            return handle.read()
    except FileNotFoundError:
        return ""


def _existing_lines(text: str) -> list[str]:
    """Split into logical lines for exact-line membership checks.

    ``str.splitlines`` drops the line terminator (including CRLF), so a CRLF
    file is compared against patterns using the same exact-line, no-terminator
    semantics as ``grep -Fx``.
    """
    return text.splitlines()


def _newline_for(text: str) -> str:
    """Pick the newline style to append with.

    A missing/empty file (fresh creation) defaults to LF. An existing file that
    uses CRLF keeps CRLF; existing bytes are never converted.
    """
    return "\r\n" if "\r\n" in text else "\n"


def _atomic_write(path: Path, content: str) -> None:
    """Write ``content`` to ``path`` atomically with mode 0644."""
    parent = path.parent
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}-", dir=str(parent))
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        raise


def merge(
    path: Path,
    patterns: list[str],
    *,
    dry_run: bool = False,
    check: bool = False,
) -> int:
    """Apply the merge contract and return a process exit code."""
    parent = path.parent
    if not parent.is_dir():
        # The synced folder does not exist yet on a fresh host. Creating it is
        # a no-op by design, so `--check` must not fail either: a host-manager
        # switch would otherwise abort before the folder is created.
        print(f"{PROG}: SKIP {path} (parent directory does not exist)")
        return EXIT_OK

    raw = _read_existing(path)
    present = set(_existing_lines(raw))

    missing: list[str] = []
    queued = set(present)
    for pattern in patterns:
        if pattern in queued:
            continue
        queued.add(pattern)
        missing.append(pattern)

    if check:
        for pattern in missing:
            print(f"{PROG}: MISSING {pattern}")
        return EXIT_MISSING if missing else EXIT_OK

    if not missing:
        if dry_run:
            print(f"{PROG}: WOULD APPEND nothing ({path} is up to date)")
        else:
            print(f"{PROG}: {path} is up to date")
        return EXIT_OK

    if dry_run:
        for pattern in missing:
            print(f"{PROG}: WOULD APPEND {pattern}")
        return EXIT_OK

    newline = _newline_for(raw)
    separator = "" if raw == "" or raw.endswith("\n") else newline
    content = raw + separator + newline.join(missing) + newline
    _atomic_write(path, content)
    print(f"{PROG}: appended {len(missing)} pattern(s) to {path}")
    return EXIT_OK


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="Non-destructively merge patterns into a .stignore file.",
    )
    parser.add_argument("--file", required=True, help="Path of the .stignore file.")
    parser.add_argument(
        "--pattern",
        action="append",
        default=[],
        metavar="PATTERN",
        help="Pattern to ensure is present; repeat for each pattern.",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be appended; write nothing.",
    )
    mode.add_argument(
        "--check",
        action="store_true",
        help="Exit 0 if every pattern is present, 1 if any is missing.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    return merge(
        Path(args.file),
        args.pattern,
        dry_run=args.dry_run,
        check=args.check,
    )


if __name__ == "__main__":
    sys.exit(main())
