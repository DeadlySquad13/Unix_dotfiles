from pathlib import Path

from invoke.runners import Result
from invoke import task, Collection, Context
from nix.nix_shell import nix_shell

import secrets
import packages.debug
import opencode.debug
import harness.harness

_pkg_debug = Collection.from_module(packages.debug, name="pkg")
_oc_debug = Collection.from_module(opencode.debug, name="opencode")
_harness = Collection.from_module(harness.harness, name="harness")

namespace = Collection(secrets, _pkg_debug, _oc_debug, _harness)

# REFACTOR:
def invoke_cmd(c: Context, *cmd, **kwargs):
    cmd_str = ' '.join(cmd)

    return c.run(cmd_str, **kwargs)


@task
def add_opencode_skill(c: Context, name: str, path: Path):
    result: Result | None = None

    with nix_shell(c, packages=["bun"]):
        result = invoke_cmd(
            c,
            # Assuming that these changes are idempotent.
            "HYGEN_OVERWRITE=1",
            "bun",
            "run",
            "hygen",
            "opencode",
            "skill",
            "--name",
            name,
            "--path",
            path,
        )

    if not result:
        return

    output = result.stdout.strip().splitlines()

    for line in output:
        if "added:" in line:
            filepath = line.split("added:")[1].strip()
            invoke_cmd(c, "git", "add", filepath)
