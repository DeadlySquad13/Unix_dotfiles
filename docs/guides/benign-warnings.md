# Benign warnings

Warnings this repository emits on purpose or as a normal side effect of its
tooling. None of the entries below blocks `nix flake check` or a deploy unless
the **Blocks** column says otherwise. Real defects are called out separately.

| Warning / source | Why it is benign | Action | Blocks |
| --- | --- | --- | --- |
| `warning: unknown flake output '<name>'` (Nix flake schema) | Nix skips non-standard top-level outputs for schema validation; it does not fail the check and does not remove the attribute. | None for the outputs listed below; consume them directly. | Nothing |
| `warning: Git tree '...' is dirty` (Nix fetcher) | Development trees and submodules are expected to be dirty; the flake records a `-dirty` revision. | Commit or stage when you need a clean revision. | Nothing |
| `warning: The option '<old>' ... has been renamed to '<new>'` (nixpkgs aliases) | `mkRenamedOptionModule` still applies the value. | Optional cleanup. | Nothing |
| `evaluation warning: system.stateVersion is not set, defaulting to <release>` | nixpkgs falls back to the current release; evaluation continues. | Set `system.stateVersion` explicitly later. | Nothing |
| `MelisStoke: xray is omitted ...` | Intentional guard when the build-time secret and/or public key is absent. | Decrypt the secret and provide the public key, then re-evaluate. | Nothing (xray is omitted) |
| `warning: The check omitted these incompatible systems: ...` | `nix flake check` only checks the current system by default. | Use `--all-systems` if you want all systems checked. | Nothing |
| `** WARNING: connection is not using a post-quantum key exchange algorithm.` | OpenSSH transport negotiation; unrelated to this repository. | Upgrade the SSH endpoint if desired. | Nothing |

## Unknown flake outputs

Nix's flake schema warns about non-standard top-level outputs and **skips**
them. The check continues, and the attributes remain usable. The current
non-standard outputs are:

| Output | Produced by | Notes |
| --- | --- | --- |
| `snowfall` | `snowfall-lib/flake/default.nix` | Snowfall metadata passed through `mkFlake`. |
| `pkgs` | `flake-utils-plus` `lib/mkFlake.nix` | Per-system package-set export. |
| `is-darwin` | helper attr in `flake.nix` | Used by deploy/check logic. |
| `isCurrentSystemDarwin` | helper attr in `flake.nix` | Used by deploy/check logic. |
| `deploySystemsMatch` | helper attr in `flake.nix` | Used by deploy/check logic. |
| `systemToDeploy` | helper attr in `flake.nix` | Used by deploy/check logic. |
| `deploy` | `flake.nix` deploy block | `deploy-rs` reads `#deploy` directly; `nix flake check` does not. |
| `public` | `flake.nix` `public` attrset | Explicit child-flake contract (ADR 0006 §1, ADR 0007). |
| `dockerConfigurations` | Snowfall virtual-system output | Generated from `systems/x86_64-docker/...` by `snowfall-lib/system/default.nix`. |
| `virtualboxConfigurations` | Snowfall virtual-system output | Generated from `systems/x86_64-virtualbox/...` by `snowfall-lib/system/default.nix`. |

Example warning:

```text
warning: unknown flake output 'deploy'
```

### `system` is not benign

An earlier revision used `system.modules.darwin` (singular) and referenced a
`mac-app-util` input that was not declared. That produced
`warning: unknown flake output 'system'` and was a **real defect**, not a benign
schema warning. The current tree uses `systems.modules.darwin` and declares the
`mac-app-util` input, so the `system` output is gone; the warning is expected to
disappear from fresh evaluations. Do not add `system` to the benign list. If a
stale checkout still emits it, update the checkout or clear the evaluation
cache.

## Dirty git tree and submodules

```text
warning: Git tree '/path/to/Unix_dotfiles' is dirty
warning: Git tree '/path/to/Unix_dotfiles/modules/home/apps/cli-utility/Wsl2_dotfiles' is dirty
```

`flake.nix` sets `inputs.self.submodules = true`, so dirty submodules are
picked up and warned about too. `nix flake metadata .` shows the result as a
`-dirty` revision, for example `45f6d65b...-dirty`. This is expected during
development and blocks nothing.

## Renamed options

These are nixpkgs aliases, so they still apply the value:

| Old option | New option | Used in | nixpkgs alias source |
| --- | --- | --- | --- |
| `services.xserver.displayManager.sddm.enable` | `services.displayManager.sddm.enable` | `modules/nixos/services/awesomewm/default.nix` | `services/display-managers/sddm.nix` |
| `services.xserver.displayManager.defaultSession` | `services.displayManager.defaultSession` | `modules/nixos/services/awesomewm/default.nix` | `services/display-managers/default.nix` |
| `hardware.pulseaudio` | `services.pulseaudio` | `systems/x86_64-linux/cake/default.nix` | `services/audio/pulseaudio.nix` |

The warning template is:

```text
warning: The option `services.xserver.displayManager.sddm.enable' defined in `.../modules/nixos/services/awesomewm/default.nix' has been renamed to `services.displayManager.sddm.enable'.
```

`mkRenamedOptionModule` also traces
`Obsolete option ... is used. It was renamed to ...`. These warnings are optional
cleanup, not deploy blockers.

## `system.stateVersion`

MelisStoke has `system.stateVersion` commented out in
`systems/x86_64-linux/MelisStoke/default.nix`, so nixpkgs falls back to the
current release:

```text
evaluation warning: system.stateVersion is not set, defaulting to <release>. Read why this matters on https://nixos.org/manual/nixos/stable/options.html#opt-system.stateVersion.
```

The check-created systems set `24.11`
(`checks/runtime-home-bridge/default.nix`,
`checks/runtime-home-bridge-nixos/default.nix`). The warning is benign and does
not block evaluation or deploy; set the option explicitly later. `terra` is a
standalone Home Manager host and does not evaluate a NixOS
`system.stateVersion`, so it is unaffected.

## MelisStoke xray omitted

`systems/x86_64-linux/MelisStoke/default.nix` adds this `warnings` entry when the
build-time xray configuration or SSH public keys are absent:

```text
MelisStoke: xray is omitted because its build-time configuration and/or
SSH public keys are not present. Decrypt
secrets/buildTime-/MelisStoke/xray-config.json with
`make decrypt-build-time-secrets NODE=MelisStoke` and ensure the
Lent__MelisStoke SSH public key exists, then re-evaluate.
```

This is an intentional guard after P1, not a failure. To clear it, decrypt the
secret and provide the public key:

```sh
make decrypt-build-time-secrets NODE=MelisStoke
# ensure ~/.ssh/Lent__MelisStoke.pub exists, then re-evaluate
```

It does not block `nix flake check` or a deploy, but xray remains omitted until
the inputs exist.

## Incompatible systems omitted

```text
warning: The check omitted these incompatible systems: aarch64-linux, x86_64-darwin, x86_64-linux
Use '--all-systems' to check all.
```

`nix flake check` checks the current system unless `--all-systems` is given.
This is expected and blocks nothing. Use `--all-systems` only when you intend to
evaluate the other systems too.

## SSH post-quantum KEX warning

OpenSSH clients can print this when the negotiated key exchange is not
post-quantum:

```text
** WARNING: connection is not using a post-quantum key exchange algorithm.
** This session may be vulnerable to "store now, decrypt later" attacks.
** The server may need to be upgraded. See https://openssh.com/pq.html
```

It comes from the SSH transport, not this repository, and blocks neither
`nix flake check` nor a deploy. Upgrade the client or server if you want the
warning to go away.

## Not all failures are benign

A full `nix flake check` can still fail for reasons outside this list:

- Pure evaluation has no `builtins.currentSystem`, so `flake.nix` fails when
  checking `isCurrentSystemDarwin` unless you run with `--impure`.
- The NVIDIA/GL checks are environment-dependent; see
  `docs/guides/testing-nix-modules.md`.

Treat those as real failures or environmental prerequisites, not as warnings to
ignore.

## See also

- `docs/guides/testing-nix-modules.md`
- `docs/adr/0006-agent-child-flake-and-repo-policy.md`
- `docs/adr/0007-agent-harness-iteration-and-merge-gates.md`
