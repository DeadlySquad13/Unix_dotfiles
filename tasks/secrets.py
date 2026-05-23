"""Decrypt SOPS‑encrypted secrets for a given NixOS node into a fixed directory.

The script reads encrypted files from `secrets/buildTime-/<node>/` and writes their
decrypted counterparts to `secrets/tmp/<node>/`. The target directory is cleared
before each run. The decrypted files can then be read by Nix at build time
(using `--impure`).
"""

import shutil
import subprocess
import sys
from pathlib import Path
from invoke.tasks import task
from invoke.context import Context
from nix.nix_shell import nix_shell

# REFACTOR:
def invoke_cmd(c: Context, *cmd, **kwargs):
    cmd_str = ' '.join(cmd)

    return c.run(cmd_str, **kwargs)


# STYLE: Ideally it substitute current file with it's encrypted version and
# then revert it after end of deploying. That way variables in the code with
# point to existing paths.
# TODO: Check [git-agecrypt](https://github.com/vlaci/git-agecrypt)
@task
def decrypt(c: Context, node: str):
    """Decrypt all secrets from `secrets/{node}` into `secrets/tmp`."""
    source_dir = Path("secrets/buildTime-") / node
    if not source_dir.is_dir():
        print(f"ERROR: secrets directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    target_dir = Path("secrets/tmp") / node
    # Clean and recreate the target directory.
    if target_dir.exists():
        shutil.rmtree(target_dir)
    target_dir.mkdir(parents=True)

    encrypted_files = list(source_dir.glob("*"))
    if not encrypted_files:
        print(f"Warning: No files found in {source_dir}", file=sys.stderr)

    with nix_shell(c, packages=["sops"]):
        for enc_file in encrypted_files:
            if not enc_file.is_file():
                continue
            decrypted_path = target_dir / enc_file.name
            print(f"Decrypting {enc_file} -> {decrypted_path}")
            try:
                invoke_cmd(c, "sops", "-d", str(enc_file), ">", str(decrypted_path))
            except subprocess.CalledProcessError as e:
                print(f"Failed to decrypt {enc_file}: {e}", file=sys.stderr)
                sys.exit(1)
