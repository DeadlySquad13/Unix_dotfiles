# Testing Nix modules

Use layered checks for reusable Nix modules. A successful evaluation does not
prove lazy values, generated scripts, or runtime services work.

## Runtime home bridge checks

The bridge has four layers of coverage and deliberately has no Docker-image
smoke test:

| Layer | Check | Purpose |
| --- | --- | --- |
| Evaluation | `checks/runtime-home-bridge/default.nix` assertion | Reject invalid mapping paths. |
| Build | `runtime-home-bridge` script package | Run `writeShellApplication` and ShellCheck. |
| Sandboxed runtime | `runtime-home-bridge` `runCommand` | Create temporary directories and verify the symlink (with and without a `zSource` chain). |
| NixOS integration | `checks/runtime-home-bridge-nixos/default.nix` | Force a full NixOS evaluation of the module (systemd unit, ordering, tmpfiles, assertions) and build the generated package. |

Run the filesystem/runtime check:

```sh
nix build .#checks.x86_64-linux.runtime-home-bridge
```

Run the NixOS integration check separately because it is heavier:

```sh
nix build .#checks.x86_64-linux.runtime-home-bridge-nixos
```

Run all discovered checks with:

```sh
nix flake check
```

## Namespaced `lib` in checks

Reusable modules under `modules/` often call `lib.ds-omega.mkIfEnabled`, which
Snowfall injects into the real system config. A standalone check's
`lib.nixosSystem` does not have that namespace. Mock it so the module body is
applied unconditionally:

```nix
libWithNamespace = lib // {
  ds-omega = lib // {
    mkIfEnabled = _opts: module: { config = module; };
  };
};
```

Pass it through `lib.nixosSystem`'s `specialArgs.lib`. Prefer this over
`pkgs.testers.nixosTest`, whose per-node `specialArgs` does not reliably let you
override the reserved `lib` module argument for the imported module.

## Choosing a test layer

1. Add an evaluation assertion for invalid option combinations.
2. Build generated packages/scripts to force builders and linters.
3. Use `runCommand` with temporary paths for safe runtime behavior.
4. Force a full NixOS evaluation (`lib.nixosSystem`) when systemd units,
   ordering, tmpfiles, or module assertions across the whole system matter.

Do not rely on `nix eval` or `nix build --dry-run` for shell-script validation:
neither executes the builder that runs ShellCheck.
