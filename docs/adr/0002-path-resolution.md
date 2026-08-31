# ADR 0002: Resolve runtime-symlink `paths` before Nix path contexts

## Status

Accepted

## Context

Homes and systems use `~/.bookmarks/<name>` as a centralized, human-friendly
namespace to reach project files, knowledge bases and shared configs. The
bookmarks are filesystem symlinks created by several different producers:

* the Home Manager `bookmarks` modules (`modules/home/bookmarks/…`), which
  create store-backed aliases; and
* the runtime-home-bridge systemd oneshot
  (`modules/nixos/services/runtime-home-bridge`), which creates plain `ln -s`
  links inside containers at boot.

The repository exposes these to Nix modules through `paths` (optionally under
`config.lib.${namespace}.paths`) and reads them through the `get-path` helper
in `lib/paths/default.nix`. `paths.<x>` is the single central point from which
modules derive high-level options such as `config.programs.opencode.aiAssistanceDir`.

A Home Manager module (`modules/programs/opencode.nix`) inspects and copies
these paths with `lib.pathIsDirectory` and `builtins.path`. When `paths.…`
pointed at a `.bookmarks` symlink, evaluation failed:

    error: path '/home/tangerineDream/.bookmarks/projects/--personal/AiAssistance__' is a symlink

## Decision

A `paths.<x>` value may legitimately be a `.bookmarks` string. What matters is
what Nix does with a *given* symlink, not that the value is a real path. The
two cases:

* **Nix-made symlinks** (`mkOutOfStoreSymlink` from the `bookmarks` modules)
  work in any context: Nix only consumes the `/nix/store/…` output path string,
  and the `.bookmarks` link materializes at activation time, never during eval.
* **Runtime symlinks** (plain `ln -s`, including `runtime-home-bridge`) work as
  strings but fail when used in a Nix **path context** — a consumer module that
  stats/copies the path, or store materialization. Symptom:
  `error: path '…' is a symlink`.

So the invariant is: **before a runtime-symlink value reaches a Nix path
context, it must be resolved to a real, build-available path.**
`lib.${namespace}.resolveRuntimePaths` (in `lib/paths/default.nix`) does this,
and it is deliberately narrow: it maps a `.bookmarks` key to its resolved real
target **only when that key is present in the host's runtime-home-bridge
catalog** (i.e. only for links the bridge actually creates). Every other value —
home-manager `mkOutOfStoreSymlink` bookmarks (`kbd`, `shared-configs`, …),
plain strings, and Nix path literals — passes through unchanged. This matters
because home-manager bookmarks work fine in any context and must not be
rewritten; only bridge-created `.bookmarks` links need resolution. If a host
does not enable the bridge, `resolveRuntimePaths` receives `{}` and resolves
nothing. The registration table comes from the shared
`lib/runtime-home-bridge` catalog so system and home agree.

Consumers keep using `get-path` (or high-level options built from it) unchanged.

## Consequences

* The `.bookmarks` namespace in `paths` is preserved; only runtime-symlink
  values used in a path context are resolved to their real targets.
* Nix never stats or copies a symlink-traversing *runtime* path, so the
  `… is a symlink` error is avoided and builds are reproducible on the strict
  host.

### Store-created symlinks are fine

Symlinks created by Home Manager's `mkOutOfStoreSymlink` (used by the
`bookmarks` modules) work fine. They point at a `/nix/store/…` derivation
output that is itself a symlink the builder created with `ln -s "<real>"`.
Nix only ever consumes the derivation's output *string*; the `ln -s` target is
baked into the build script as text, so no symlink-traversing path is ever
statted or copied. The `.bookmarks` link itself only materializes at activation
time, as a runtime output.

### Runtime symlinks error in specific scenarios

The failure is specific to **runtime symlinks** — links whose target does not
exist until after the build and that Nix must then dereference or copy. This
includes plain `ln -s` in scripts and the `runtime-home-bridge` systemd
oneshot. These error only when the path is used in a Nix **path context**:

1. **Stat/copy by a module** — e.g. `lib.pathIsDirectory` (`readFileType`) or
   `builtins.path { … }` inside consumer modules such as
   `programs.opencode.skills`. Symptom:

   ```
   error: path '/home/…/.bookmarks/projects/…/AiAssistance__' is a symlink
   ```

2. **Store materialization** — a symlink-traversing path passed to
   `builtins.path`, string-interpolated into a derivation, or used as a
   derivation input. Nix must copy it and refuses.

3. **`pathExists` checks against a not-yet-created runtime target** — a path
   that points into the container runtime (`/ztangerineDream/…`) does not exist
   during an image build. Symptom:

   ```
   error: path '…/AiAssistance__/_skills/…' does not exist
   ```

Uses that are *not* path contexts are always safe: exposing the value as a plain
string (config text, script args), building a config text string, and placing a
store-backed symlink via `mkOutOfStoreSymlink`.

### Nix-version nuance and `readlink`

* On newer Nix versions, `readFileType` returns `"symlink"` instead of erroring
  and store-copies follow symlinks, so the same bad expression can build
  *silently* while doing the wrong thing. The strict host fails loudly, which
  is a feature.
* Nix has no `readlink` builtin and cannot resolve a symlink at evaluation
  time. "Dereference" workarounds (store copies, `builtins.path` with
  `followSymlinks`) produce immutable snapshots, which are wrong for live
  working directories such as opencode skills; prefer declaring the real path.

## Pitfall: `~/.bookmarks` vs the runtime bridge

The runtime-home-bridge (ADR 0001) creates `.bookmarks` links **only inside the
container after boot**. For a NixOS image build on the host, that resolved
target does not exist yet, so pointing `paths.…` at the bridge *target* can
produce a different failure:

    error: path '…/AiAssistance__/_skills/add-opencode-skill-to-unix-dotfiles' does not exist

There are two distinct `.bookmarks` worlds:

* **Build host** (`/home/ds13`): the real target is already available, for
  example `.bookmarks/projects` → `/home/ds13/Projects`.
* **Container runtime** (`/ztangerineDream/…`): created by the bridge, only
  present after boot.

Which world applies depends on *when* the Nix expression is evaluated. For an
image build, `paths.<x>` must point at the **build-host-available real path**
(such as `/home/ds13/Projects`), matching hosts like `darkGreen-tangerineDream`
that use `${deploymentHostHome}/Projects`. The `resolveRuntimePaths` registrations
must come from the source that is valid for the consumer's lifespan.

## Systems that must follow the resolve mechanism

Every consumer that hands `paths` values to Nix as paths, and every host whose
paths are bridged at runtime, must run their home `paths` through
`resolveRuntimePaths`. This includes all docker systems such as
`darkGreen-tangerineDream` (and its `_inner` / `-green` variants): their
`projects`, `shared-configs` and `shared-scripts` entries are created by the
runtime bridge and would otherwise resolve to `.bookmarks` symlinks.

## Why resolution (and the symptom without it)

Nix stats the on-disk object, not its provenance. A runtime symlink is
indistinguishable to Nix from any other symlink, and the moment a Nix path
expression touches a runtime symlink, evaluation or the store copy fails with:

    error: path '…' is a symlink

So a value that may be a runtime symlink (or point into a runtime-only bridge
target) must be resolved to a real, build-available path before it reaches a
Nix **path context** — hence `resolveRuntimePaths`. `paths.<x>` keeps a
human-friendly `.bookmarks` string; the convenience symlink
(`.bookmarks/<x>`) remains a runtime output produced from the real path, never
the value Nix consumes unless resolved first.

The same rule applies to placeholders that are not symlinks but point into a
runtime-only target (like the bridge's `/ztangerineDream/…`): they are
unavailable at build time and fail with `… does not exist`.

## Synchronization

Update this ADR when changing path resolution, adding a new bookmark producer,
or touching the runtime-home-bridge catalog and its `resolveRuntimePaths`
registration.
