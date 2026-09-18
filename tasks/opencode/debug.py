"""Debug helper tasks for OpenCode wiring in this repository.

Covers plugins / skills / agents / produced home config for a Home Manager
target. Each task is written for ONE consumer, marked in its docstring:
- [machine] — single-line/JSON output, safe to consume programmatically;
- [human]   — readable report, final `PATH:` line copyable into ranger.

See Makefile.opencode for make wrappers, Makefile.opencode-mcp for the
mcp-logseq oracle (Logseq-ACL agents), and the agent skills
(`opencode-plugins`, `opencode-skills`, `opencode-agents`).
"""

import json
import re
import subprocess
import sys
import os
import shutil
import tempfile
from glob import glob
from pathlib import Path

from invoke import Context, task

LOG_DIR_FALLBACK = "~/.local/share/opencode/log"

# Node builtin module names — the only bare specifiers allowed in a bundle.
NODE_BUILTINS = {
    "assert", "async_hooks", "buffer", "child_process", "cluster",
    "console", "constants", "crypto", "dgram", "diagnostics_channel",
    "dns", "domain", "events", "fs", "http", "http2", "https", "inspector",
    "module", "net", "os", "path", "perf_hooks", "process", "punycode",
    "querystring", "readline", "repl", "stream", "string_decoder",
    "sys", "timers", "tls", "trace_events", "tty", "url", "util", "v8",
    "vm", "wasi", "worker_threads", "zlib",
}


def _run(cmd, **kw):
    return subprocess.run(cmd, text=True, capture_output=True, **kw)


def _git_bin() -> str:
    which = shutil.which("git")
    if which:
        return which
    fallbacks = sorted(glob("/nix/store/*-git-*/bin/git"))
    if fallbacks:
        return fallbacks[-1]
    sys.exit("no git binary found (PATH and /nix/store)")


def _stage_all():
    """Stage repo changes (REQUIRED before any flake eval on this host:
    Nix 2.33.3's dirty-tree source excludes untracked files). Not a commit."""
    _run([_git_bin(), "add", "-A"])


def _eval_home_json(host: str, attr_suffix: str) -> str:
    res = _run(
        [
            "nix", "eval", "--extra-experimental-features", "nix-command flakes",
            "--impure", "--json",
            f'.#homeConfigurations."{host}"{attr_suffix}',
        ]
    )
    if res.returncode != 0:
        sys.exit(f"nix eval failed ({host}{attr_suffix}):\n{res.stderr[-2000:]}")
    return res.stdout.strip()


# ---------------------------------------------------------------- machine ---

@task
def eval(c: Context, host: str = "ds13@salt",
         attr: str = "config.programs.opencode.settings"):
    """[machine] Print raw JSON of any attr under a homeConfiguration."""
    print(_eval_home_json(host, f".{attr}"))


@task
def plugins(c: Context, host: str = "ds13@salt"):
    """[machine] The settings.plugin JSON list. Healthy = ONLY file://
    entries; a bare package name would npm-install at startup."""
    print(_eval_home_json(host, ".config.programs.opencode.settings.plugin"))


@task
def agent(c: Context, host: str = "ds13@salt", name: str = ""):
    """[machine] Full JSON config of ONE agent (required: name=<agent>)."""
    if not name:
        sys.exit("usage: invoke opencode.agent --host=<h> --name=<n>")
    print(_eval_home_json(host, f'.config.programs.opencode.agents."{name}"'))


# ------------------------------------------------------------------ human ---

@task
def skills(c: Context, host: str = "ds13@salt"):
    """[human] Configured skills, one `name = value` per line, sorted."""
    data = json.loads(_eval_home_json(host, ".config.programs.opencode.skills"))
    for name, value in sorted(data.items()):
        print(f"{name} = {value}")


@task
def agents(c: Context, host: str = "ds13@salt"):
    """[human] Configured agents, one `name: summary` per line, sorted.
    For Logseq-ACL contract auditing use `make mcp-logseq-debug`."""
    data = json.loads(_eval_home_json(host, ".config.programs.opencode.agents"))
    for name, value in sorted(data.items()):
        summary = ""
        if isinstance(value, dict):
            summary = value.get("description") or value.get("mode", "")
        elif isinstance(value, str):
            summary = value
        print(f"{name}: {summary}")


@task
def plugin_verify(c: Context, host: str = "ds13@salt"):
    """[human] Full sanity per file:// entry configured for <host>:
      1) store path EXISTS on this machine (stale opencode.json after
         rebuilds is the #1 confusion);
      2) no bare `from "<spec>"` imports left in the bundle (vendoring
         complete; a bare spec makes OpenCode's file:// loader fall back to
         an implicit npm registry install);
      3) offline bun import finishes in <10s (a hang on 'Resolving' means
         step 2 passed but something else resolves at import — investigate
         with `make package-bare-imports`).
    Exits 1 on the first failing path; every checked path also prints a
    `PATH:` line for ranger.
    """
    _run([_git_bin(), "add", "-A"])
    raw = _eval_home_json(host, ".config.programs.opencode.settings.plugin")
    paths: list[str] = []
    for entry in json.loads(raw):
        match = re.search(r"/nix/store/[^\s\"']+/dist/index\.js", str(entry))
        if match:
            paths.append(match.group(0))
        else:
            print(f"WARNING: bare (npm) plugin entry — registry hang risk: "
                  f"{entry}", file=sys.stderr)
    if not paths:
        print("OK: no file:// plugin entries configured.")
        return

    bun = shutil.which("bun") or (sorted(glob("/nix/store/*-bun-*/bin/bun")) or [None])[-1]
    if not bun:
        sys.exit("no bun binary found (PATH and /nix/store)")

    failed = False
    for path in paths:
        print(f"-> checking {path}")
        if not Path(path).is_file():
            print("FAIL: store path MISSING on this host (stale config? re-switch)")
            failed = True
            continue
        specs = {m.group(1) for m in re.finditer(
            r'(?:from\s+|require\(\s*)["\']([^"\']+)["\']',
            Path(path).read_text(errors="replace"))}
        bad = [s for s in sorted(specs)
               if not s.startswith(".") and
               (s not in NODE_BUILTINS) and not s.startswith("node:")]
        if bad:
            print(f"FAIL: bare specifier(s) not vendored: {bad}")
            failed = True
        else:
            print("OK: no bare specifiers.")
        with tempfile.TemporaryDirectory() as tmp:
            env = {**os.environ, "BUN_INSTALL_CACHE_DIR": str(Path(tmp) / "buncache")}
            res = subprocess.run(
                ["timeout", "10", bun, "-e",
                 f'await import("file://{path}"); console.log("import OK")'],
                cwd=tmp, text=True, capture_output=True, env=env)
        if res.returncode != 0:
            print(f"FAIL: bundle load (rc={res.returncode}): {res.stdout}{res.stderr}")
            failed = True
        else:
            print(res.stdout.strip())
        # The plugin package root (drop dist/index.js).
        print(f"PATH: {Path(path).parent.parent}")
    sys.exit(1 if failed else 0)


@task
def home_build(c: Context, host: str = "ds13@salt", maxdepth: int = 4):
    """[human] Build the activation derivation, list generated OpenCode
    files, end with `PATH: <.../home-files/.config/opencode>` for ranger —
    inspect opencode.json (plugin file:// entry), skill/, agent/ directly.
    Machine equivalent for the drv path: `make oc-home-eval`.
    """
    _run([_git_bin(), "add", "-A"])
    res = _run(
        ["nix", "build", "--extra-experimental-features", "nix-command flakes",
         "--impure", "--no-link", f'.#homeConfigurations."{host}".activationPackage'])
    if res.returncode != 0:
        sys.exit(f"activation build failed:\n{res.stderr[-3000:]}")
    base = Path("result/home-files/.config/opencode")
    if not base.is_dir():
        sys.exit(f"no opencode dir in result: {base}")
    for line in sorted(str(p) for p in glob(f"{base}/**", recursive=True)):
        print(line)
    print(f"PATH: {base.resolve()}")


@task
def logs(c: Context, lines: int = 100):
    """[human] Tail the newest opencode log; final `PATH:` for ranger/less.
    Reading order: repeated `ResolveMessage: Cannot find module '<spec>'
    from '<store-path>'` = plugin bundle not self-contained. Long gaps
    between `GET /event` heartbeats are symptom, not cause."""
    log_dir = Path.home() / ".local/share/opencode/log"
    if not log_dir.is_dir():
        sys.exit(f"no log dir: {log_dir}")
    candidates = sorted(log_dir.iterdir(), key=lambda p: p.stat().st_mtime)
    if not candidates:
        sys.exit("no log files")
    latest = candidates[-1]
    for line in latest.read_text(errors="replace").splitlines()[-lines:]:
        print(line)
    print(f"PATH: {latest}")
