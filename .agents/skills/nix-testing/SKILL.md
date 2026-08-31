---
name: nix-testing
description: This skill should be used when adding or running tests for Nix expressions, NixOS modules, generated scripts, systemd services, or repository flake checks.
---

# Test Nix configuration in layers

Read `docs/guides/testing-nix-modules.md` before adding checks. Keep fast,
focused checks under `checks/<name>/default.nix`; Snowfall exports them as
`checks.<system>.<name>`.

## Select the smallest sufficient layer

1. Use Nix evaluation/assertions for invalid options and configuration
   contracts.
2. Build a generated package or `writeShellApplication` to execute builders and
   ShellCheck.
3. Use `pkgs.runCommand` with `$TMPDIR` or another safe fixture for filesystem
   behavior.
4. Use `pkgs.testers.nixosTest` for NixOS/systemd/user/boot integration.

Do not use an image build when a focused check covers the behavior. Do not
treat `nix eval` or `nix build --dry-run` as proof that generated shell code
works.

## Implement a check

- Place the check at `checks/<name>/default.nix` to use Snowfall discovery.
- Return one derivation per check directory. Create separate check directories
  for independently runnable fast and VM tests.
- Build exactly the generated script/package in a build check so its lint phase
  runs.
- Make runtime fixtures disposable. Never point `runCommand` tests at real
  homes, secret paths, Docker sockets, mounts, or user state.
- Make VM tests assert externally observable behavior: service active, file
  created, symlink target, or network response.

## Run and diagnose

```sh
nix build .#checks.x86_64-linux.<name>
nix flake check
nix log /nix/store/<failed>.drv
```

Inspect generated output and derivation differences after changing option
wiring. A passing build can still test the wrong disabled branch if the target
or fixture does not consume the changed option.
