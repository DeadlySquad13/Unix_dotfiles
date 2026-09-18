"""Debug helper tasks for Snowfall packages in `packages/<name>/`.

Each task is written for ONE consumer, marked in its docstring:
- [machine] — single-line output only, safe to consume in pipelines
  (e.g. `ranger "$(invoke --search-root=./tasks pkg.out-path)"`);
- [human]   — readable report +/or explicit FAIL/OK verdicts.

See Makefile.packages-debug for the make wrappers and the host notes
(staging-before-build, --impure eval, git/bun binary fallbacks).
"""

import re
import subprocess
import sys
import tempfile
import shutil
import os
from glob import glob
from pathlib import Path

from invoke import Context, task

GIT_FALLBACK_GLOB = "/nix/store/*-git-*/bin/git"
BUN_FALLBACK_GLOB = "/nix/store/*-bun-*/bin/bun"

# Node builtin module names — allowed bare specifiers in a bundle.
NODE_BUILTINS = {
    "assert", "async_hooks", "buffer", "child_process", "cluster",
    "console", "constants", "crypto", "dgram", "diagnostics_channel",
    "dns", "domain", "events", "fs", "http", "http2", "https", "inspector",
    "module", "net", "os", "path", "perf_hooks", "process", "punycode",
    "querystring", "readline", "repl", "stream", "string_decoder",
    "sys", "timers", "tls", "trace_events", "tty", "url", "util", "v8",
    "vm", "wasi", "worker_threads", "zlib",
}


def _is_builtin(spec: str) -> bool:
    return spec in NODE_BUILTINS or spec.startswith("node:")


def _run(cmd: list[str], **kw):
    return subprocess.run(cmd, text=True, capture_output=True, **kw)


def _git_bin() -> str:
    """Path of a git binary: PATH first, then /nix/store fallback."""
    which = shutil.which("git")
    if which:
        return which
    fallbacks = sorted(glob(GIT_FALLBACK_GLOB))
    if fallbacks:
        return fallbacks[-1]
    sys.exit("no git binary found (PATH and /nix/store)")


def _bun_bin() -> str:
    """Path of a bun binary: PATH first, then /nix/store fallback."""
    if shutil.which("bun"):
        return "bun"
    fallbacks = sorted(glob(BUN_FALLBACK_GLOB))
    if fallbacks:
        return fallbacks[-1]
    sys.exit("no bun binary found (PATH and /nix/store)")


def _stage_all():
    """Stage repository changes so the Nix dirty git-tree source includes
    them. required before any flake eval/build on this host
    (Nix 2.33.3 excludes untracked files). Staging is NOT a commit."""
    _run([_git_bin(), "add", "-A"])


def _build_out_path(pkg: str) -> str:
    """Return the out path of the flake package (top-level attribute)."""
    _stage_all()
    res = _run(
        [
            "nix", "build", "--extra-experimental-features", "nix-command flakes",
            "--impure", "--no-link", "--print-out-paths", f".#{pkg}",
        ]
    )
    if res.returncode != 0:
        sys.exit(f"package build failed for {pkg}:\n{res.stderr[-2000:]}")
    return res.stdout.strip().splitlines()[-1]


def _artifact(pkg: str, entry: str) -> str:
    out = _build_out_path(pkg)
    if not (Path(out) / entry).is_file():
        sys.exit(f"MISSING: {entry} in {out}")
    return out


@task
def out_path(c: Context, pkg: str = "opencode-ssh-session"):
    """Print ONLY the store path of the built package (machine-friendly)."""
    print(_build_out_path(pkg))


@task
def contents(c: Context, pkg: str = "opencode-ssh-session", maxdepth: int = 3):
    """List the out-path tree; last line `PATH: <store-path>` for humans.

    A human should take the PATH line and run:  ranger <PATH> — interactive
    investigation; agents should stay with `out-path` (single line).
    """
    out = _build_out_path(pkg)
    rows = sorted(_run(["find", out, "-maxdepth", str(maxdepth)]).stdout.splitlines())
    for line in rows:
        print(line)
    print(f"PATH: {out}")


@task
def bare_imports(c: Context, pkg: str = "opencode-ssh-session", entry: str = "dist/index.js"):
    """List import specifiers of a JS artifact (and flag non-vendored ones).

    Healthy output: only node builtins (path/fs/...) besides relative paths
    (./, ../). Any bare name (`@scope/x`, `zod`) means NOT fully vendored,
    and OpenCode's file:// plugin loader would make Bun fall back to an
    implicit npm registry install (the eternal startup-hang signature).
    Exit code: 0 when clean, 1 when at least one bare specifier is left.
    """
    out = _artifact(pkg, entry)
    target = Path(out) / entry
    specifiers = {
        match.group(1)
        for match in re.finditer(
            '(?:from\\s+|require\\(\\s*)["\']([^"\']+)["\']',
            target.read_text(errors="replace"),
        )
    }
    for spec in sorted(specifiers):
        print(spec)
    bad = [s for s in sorted(specifiers)
           if not s.startswith(".") and not _is_builtin(s)]
    if bad:
        sys.exit(f"FAIL: {len(bad)} bare specifier(s) not vendored: {bad}")
    print("OK: no bare specifiers (only builtins/relative).")


@task
def import_test(
    c: Context,
    pkg: str = "opencode-ssh-session",
    entry: str = "dist/index.js",
    timeout: int = 10,
):
    """Offline load test: import the artifact with bun from an EMPTY cwd,
    isolated bun cache, hard timeout. A hang on 'Resolving' means a bare
    specifier survived the build (an implicit registry fallback attempted);
    healthy bundles finish well under the timeout. Exit code 1 on failure.
    """
    out = _artifact(pkg, entry)
    bun = _bun_bin()
    with tempfile.TemporaryDirectory() as tmp:
        cmd = [
            "timeout", str(timeout), bun,
            "-e", f'await import("file://{out}/{entry}"); console.log("import OK")',
        ]
        env = {**os.environ, "BUN_INSTALL_CACHE_DIR": str(Path(tmp) / "buncache")}
        res = subprocess.run(cmd, cwd=tmp, text=True, capture_output=True, env=env)
    if res.returncode != 0:
        sys.exit(f"FAIL (rc={res.returncode}, timeout={timeout}): "
                 f"{res.stdout}{res.stderr}")
    print(res.stdout.strip())
    print(f"OK: imported offline in under {timeout}s ({out}/{entry}).")
