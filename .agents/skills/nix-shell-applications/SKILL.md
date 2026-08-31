---
name: nix-shell-applications
description: This skill should be used when creating or debugging Nix-generated shell scripts, especially pkgs.writeShellApplication scripts and NixOS services that fail during build because ShellCheck runs only when the derivation is built.
---

# Debug Nix-generated shell applications

Use this skill for scripts generated with `pkgs.writeShellApplication`,
`pkgs.writeShellScript`, or service wrappers whose shell code is embedded in a
Nix string.

## Know the evaluation boundary

- Treat `nix eval` as option/assertion validation, not shell-script validation.
- Treat `nix build --dry-run` as dependency planning, not execution of builders.
- Build the derivation containing the script to run `writeShellApplication`'s
  ShellCheck phase. A configuration can evaluate successfully while its shell
  script still fails at build time.
- Inspect the failing derivation and its complete log:

  ```sh
  nix log /nix/store/<name>.drv
  ```

## Debug a ShellCheck failure

1. Read the reported generated script path and line number from the build log.
2. Map that line back to the Nix multi-line string. Inspect conditional Nix
   interpolation carefully: all branches become literal shell text in the
   generated script.
3. Fix the generated control flow, not merely the warning. For example, do not
   generate an unconditional `exit 0` after a branch that always calls a helper
   ending in `exit 1`:

   ```nix
   # Bad when cfg.required is true: ShellCheck sees unreachable exit 0.
   if [ ! -e "$config_file" ]; then
     ${lib.optionalString cfg.required ''fail "missing config"''}
     exit 0
   fi

   # Good: generate exactly one terminating branch.
   if [ ! -e "$config_file" ]; then
     ${
       if cfg.required
       then ''fail "missing config"''
       else "exit 0"
     }
   fi
   ```

4. Build the narrow derivation again. If a system image is the only exposed
   target, build the image rather than only evaluating it.
5. Test runtime behavior separately where practical, including both branches of
   conditionals and malformed input paths.

## Validate generated scripts

Use this progression:

```sh
# Check module options and Nix assertions.
nix eval <target>

# Confirm planned dependencies; this does not run ShellCheck.
nix build <target> --dry-run

# Required for writeShellApplication: execute builders and ShellCheck.
nix build <target>
```

After a successful build, locate the generated application and inspect it if
control flow is non-trivial:

```sh
nix-store --query --outputs /nix/store/<failing-or-built>.drv
```

Run focused behavioral tests outside the target system only when the script can
operate safely against temporary inputs. Do not run scripts that modify real
homes, mounts, secrets, or Docker state without an isolated fixture.

## Improve repository testability

Prefer exposing a narrow flake check for reusable shell-generating modules.
The check should import the module with a minimal valid configuration and build
an output depending on the generated script/service. This makes ShellCheck run
without building a full Docker tarball.

For `runtime-home-bridge`, a useful future check should cover:

- `required = false` with a missing runtime config, which exits successfully;
- `required = true` with a missing runtime config, which fails clearly;
- valid relative mappings; and
- rejected absolute, newline-containing, and `..` mappings.

No extra infrastructure is required to fix or manually validate a script:
`writeShellApplication` already provides ShellCheck during a real build.
Add a focused flake check only when full image builds are too expensive or this
class of script changes frequently.

Read `docs/guides/testing-nix-modules.md` for the repository's layered check
pattern, including `runCommand` and NixOS VM integration tests.
