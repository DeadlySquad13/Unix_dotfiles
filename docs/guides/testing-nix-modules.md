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

## Paths and bookmarks checks

Coverage for the `paths`/`resolveRuntimePaths` machinery and the bookmark pipeline:

| Check | Layer | Purpose |
| --- | --- | --- |
| `checks/paths` | Unit | `get-path` and `resolveRuntimePaths`: bridge-managed `.bookmarks` keys resolve to real paths; multiple keys resolve independently; non-bridge `.bookmarks` keys (e.g. `kbd`, `shared-configs`) and Nix path literals pass through unchanged; an empty resolutions table resolves nothing; `get-path` returns a path or a `~`-expanded string. |
| `checks/bookmarks` | Integration | The full pipeline mirroring a docker host: `resolveRuntimePaths` against the runtime-home-bridge catalog resolves `projects`, `shared-configs` and `shared-scripts` to symlink-free real paths while leaving non-bridge keys intact. |

Run just these:

```sh
nix build .#checks.x86_64-linux.paths
nix build .#checks.x86_64-linux.bookmarks
```

Per the repo convention the checks import `lib/paths` and `lib/runtime-home-bridge`
directly with a minimal mock namespace, because the repo lib is not exposed
through a standalone check's injected `lib` merge.

Shortcuts via the Makefile (pass the flake host as the target argument):

```sh
make bookmarks-check                             # build both checks
make bookmarks-paths darkGreen-tangerineDream_inner   # resolved .paths for a host
make bookmarks-skills darkGreen-tangerineDream_inner  # opencode skillPaths for a host
make bookmarks-catalog darkGreen-tangerineDream       # system bridge variant catalog
```

The `paths` checks are what guard against the `path '…' is a symlink` error:
they assert the resolved value is a real path before it reaches any Nix path
context. See `docs/adr/0002-path-resolution.md`.

## mcp-logseq check

`checks/mcp-logseq/default.nix` is an evaluation-layer check that asserts the
per-agent Logseq namespace ACL contract derived by
`modules/home/apps/ai-assistance/opencode/mcp.nix`. It imports the real module
and sources the global namespace values from the new
`modules/home/apps/ai-assistance/opencode/logseq-profiles.nix` module (only the
host glue `logseqEnvironmentFile`/`logseqHost` is a fixture), and aborts loudly
on any mismatch:

| Check | Layer | Purpose |
| --- | --- | --- |
| `checks/mcp-logseq` | Evaluation | Assert the 7 derived `logseq-<name>` servers against the oracle (exact `LOGSEQ_WRITE_INCLUDES` / `LOGSEQ_INCLUDE_NAMESPACES` / `LOGSEQ_EXCLUDE_NAMESPACES`, ports, stdio pin, `LOGSEQ_API_URL`, environmentFile); per-agent tool-grant isolation (no cross-agent `logseq-*` glob, including the `<agent>-kbn` summarizer counterparts whose set is exactly `{logseq-kbn*, logseq-<parent>*}`); the `permission.task` delegation wiring (each parent grants exactly its own `<agent>-kbn`); counterpart personas (`mode: subagent`, `hidden: true`, `permission.bash = deny`); and that the three global namespace options resolve identically from `logseq-profiles.nix`. |

Run just this check:

```sh
nix build .#checks.x86_64-linux.mcp-logseq
```

The `mcp-logseq` flake check only exists once the new files are git-tracked
(Snowfall discovers checks from the git tree); a bare `git add` suffices. The
`checks/mcp-logseq/debug.nix` debug dump (per-agent ACL contract as JSON) is
wired to the Makefile independently and is not a check. See
`docs/guides/logseq-agent-namespaces.md#debugging`.

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
