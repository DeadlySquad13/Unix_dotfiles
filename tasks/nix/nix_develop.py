import subprocess
from invoke import task


@task
def nix_develop(ctx, shell="data"):
    """
    Pre-task: if Nix flake shell is available, make ctx.run use it.
    Falls back silently to whatever is on PATH.
    """
    cmd_prefix = ["nix", "develop", f".#{shell}", "-c"]
    try:
        # Quick check: run 'true' inside the flake shell
        subprocess.run(cmd_prefix + ["true"], check=True,
                       capture_output=True, text=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        # Nix not installed or flake build fails → do nothing
        return

    # Success: wrap ctx.run so every command goes through nix develop
    original_run = ctx.run

    def run_with_nix(cmd, **kwargs):
        return original_run(f"nix develop .#{shell} -c {cmd}", **kwargs)

    ctx.run = run_with_nix
