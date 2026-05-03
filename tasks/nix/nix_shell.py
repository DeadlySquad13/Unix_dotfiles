from contextlib import contextmanager
import subprocess
import tempfile
from invoke.context import Context
from invoke import task


# REFACTOR:
def invoke_cmd(c, *cmd, **kwargs):
    cmd_str = ' '.join(cmd)

    return c.run(cmd_str, **kwargs)


def _nix_shell(c, packages):
    """
    Pre‑task: if nix-shell works, create a temporary file that captures
    the environment of `nix-shell -p <packages>`. Store the file path
    in c.config. If Nix is not available, leave it empty (fallback).
    """
    if not packages:
        return

    try:
        # `env` inside nix-shell prints all environment variables
        env_output = subprocess.check_output(
            ["nix-shell", "-p", *packages, "--run", "env"],
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return

    # Write a short script that source'ing will export these variables
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".sh", delete=False, prefix="nix_env_"
    ) as f:
        for line in env_output.strip().split("\n"):
            if "=" in line:
                key, value = line.split("=", 1)
                # export each variable, quoting the value for safety
                f.write(f"export {key}='{value}'\n")
        env_file = f.name

    # Store the file path in c.config for this session.
    c.config["nix_env_file"] = env_file


@contextmanager
def nix_shell(c: Context, packages):
    _nix_shell(c, packages)

    env_file = c.config.get("nix_env_file")

    with c.prefix(f"source {env_file}" if env_file else ""):
        try:
            yield
        finally:
            pass
