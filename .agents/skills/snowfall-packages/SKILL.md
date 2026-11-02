---
name: snowfall-packages
description: This skill should be used when creating, building, or debugging a Nix package in this Unix_dotfiles repository's Snowfall packages tree — placement, scaffolding, exposing via pkgs.<namespace>, attribute-path discovery with flake-utils-plus, and the host's dirty-tree staging requirement.
---

# Create a Snowfall package

Use this skill when adding a reusable package to this repository. Module
placement/enabling belongs to the `snowfall-modules` skill; this covers the
`packages/` tree.

## Layout

- One package per directory: `packages/<name>/default.nix`. Snowfall
  auto-discovers every such default.nix (nested directories under `packages/`
  do **not** produce nested attribute paths — a parent directory name is
  incorporated into child package naming, so keep one package = one directory).
- Packages are exposed namespaced as `pkgs.${namespace}.<name>` in Nix
  evaluations, and — via flake-utils-plus — largely also at the **top level**
  of the flake (`nix build .#<name>`). Do not assume the attribute path;
  probe:
  ```sh
  nix eval .#packages.x86_64-linux --apply 'attrs: with builtins; attrNames attrs' ...
  nix build .#<name>            # try merged top-level first
  ```
  If a top-level `nix build .#<name>` fails with "flake does not provide
  attribute", inspect what *is* visible before concluding the package is
  broken (store-path of the flake source may simply omit it — see staging).

## Scaffolding

Model a new package on existing ones (`packages/kroki-cli/default.nix`,
`packages/opencode-ssh-session/default.nix`):

- Take external sources (other flakes) as module arguments `(..., inputs,? pkg, lib, ...)`.
- Wrap behavior in `stdenv.mkDerivation` (or a builder); keep derivations
  pure: pin sources by rev + nar-hash, no network in build phases.
- For JS/bun projects see the `packaging-js-repos` skill.

## MUST: stage new files before any flake operation

On this host (Nix 2.33.3) the dirty git-tree fetcher **excludes untracked
files**. A newly created package directory is invisible to `nix build`/`nix
eval` of the flake until it is **at least staged**:

```sh
git add packages/<new-name>/        # staging only; commits are separate
nix build .#<new-name> --no-link --print-out-paths
```

Symptom otherwise: builds resolve to an *older* flake source and fail with
"does not provide attribute", or unrelated-sounding package errors ("harpoon"
appearing instead of your package). Verify with
`nix-store --query --references` / diffing the flake `source` store path, or
`git status` to confirm your files were staged at the time of the build.

## Validate

```sh
# 1. Build green and check the output contents — do not stop at success.
nix build .#<name> --no-link --print-out-paths
ls -R $(nix-store -q --deriver /nix/store/<hash>-<name>/ 2>/dev/null >/dev/null; echo) # outline of the out path instead:
nix build .#<name> --no-link >/dev/null; find result -maxdepth 3

# 2. If the package feeds a module: inspect the consumer output (see the
#    snowfall-modules skill) and confirm the store path / file content flows
#    through — e.g. grep the generated config for the expected file:// entry.
```

- Environment on this host: `nix eval` of home configurations may need
  `--impure` (the repo contains pre-existing tilde-path runtime references);
  that's a pre-existing condition, not a sign your change is wrong.
- The working dir under bash must be below `$HOME` (see snowfall-modules
  host quirk notes).
- Never commit secrets; never commit without being asked to.
