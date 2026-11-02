---
name: packaging-js-repos
description: This skill should be used when packaging an npm/node/bun JavaScript/TypeScript repository or plugin for this Unix_dotfiles repository with Nix — choosing target (bun vs node), avoiding npm registry access at build time, vendoring/keeping-external dependencies, and verifying the bundle actually loads offline.
---

# Package an npm/node/bun repo with Nix

Use this skill when wrapping a JS/TS project (a plugin, CLI, library) as a
Snowfall package under `packages/<name>/default.nix`. Read
`packages/kroki-cli/default.nix` or `packages/opencode-ssh-session/default.nix`
for house scaffolding first.

## Rule zero: no network at build time

The user's network times out on npm. `bun install`, `npm install`,
`fetchNpmDeps`, and any derivation command that touches the registry are
forbidden. Everything that needs to fetch must be hash-pinned by Nix:

- The project source itself: a `flake = false` input pinned by commit rev
  (see `flake.nix` — `opencode-ssh-session`, `opencode`, `mcp-logseq`
  follow this pattern), or a narHash-pinned `fetchFromGitHub`.
- Runtime dependencies: vendored into the bundle (see below), each from a
  pinned source. Never let the builder fetch.

## Decide: bundle it fully or keep externals

OpenCode plugins and anything loaded by a host that does **not** resolve bare
specifiers need a **fully self-contained bundle**. The deciding question:
*"who imports the output, and can that host resolve the imports?"*

- Loaded by OpenCode via the `file://` plugin path → **bundle everything
  (no `--external`)**. OpenCode does not alias or inject `@opencode-ai/plugin`;
  with a bare specifier left in the bundle, Bun falls back to an implicit
  npm registry install → indefinite hang, plus repeated
  `ResolveMessage: Cannot find module ...` errors in the OpenCode log.
- Loaded by your own wrapper/entry with a `node_modules` you control →
  `--external` is fine, but you must ship that `node_modules`.

Pattern for vendoring (from the `opencode-ssh-session` fix):

```nix
# Symlink (or copy) each runtime dep at a pinned rev into the build.
# Bun/TS sources may be symlinked directly — bun build transpiles them.
mkdir -p node_modules/@opencode-ai
ln -s ${opencodeSrc}/packages/plugin node_modules/@opencode-ai/plugin
```

If a dependency's repo `package.json` exports point at a **not-yet-built**
`dist`, replace the manifest with a minimal one pointing at the true entry
(e.g. `src/index.ts`), as the zod 4.x vendoring in
`packages/opencode-ssh-session/default.nix` does.

## Target: match the loader runtime

- OpenCode runs on **Bun** → use `bun build --target bun` when the artifact is
  consumed by OpenCode, not `--target node` (README/task patterns that assume
  npm-installed plugins target node; the `file://` import path differs).
- Everything else: match the actual consumer; when unsure, prefer the runtime
  of the embedding process.

## Verify the build output — do not stop at a green build

Every JS package build must pass both checks:

```sh
# 1. No bare specifiers remain (only node builtins / relative paths).
grep -oE '(from\s*["'"'"']|require\(["'"'"'])[^"''"'.][^"'"'"']*' \
  <out>/dist/index.js | sort -u

# 2. Fast offline import — proves no registry fallback would be attempted.
cd "$(mktemp -d)"                      # empty cwd: no project node_modules nearby
timeout 10 bun -e 'await import("file://<out>/dist/index.js"); console.log("ok")'
```

- Check 1 must list only builtins (`path`, `fs`, ...) and relative paths.
- Check 2 must finish well under the timeout. A hang on "Resolving" means a
  bare specifier survived and Bun is attempting an npm install.
- When the artifact exports a factory (a plugin), also confirm the exports
  (`Object.keys(m)`) and constructible surfaces (e.g. zod `.safeParse`
  is a function) — see the opencode-plugins skill.

## Pitfalls seen on this host

- Nix attr names contain dashes and are not valid bash variable references —
  never interpolate an attr name like `$zod-src` into a shell command; it
  parses as empty-var `${zod}` + literal `-src` (`cp: invalid option -- 'c'`).
  Use explicit camelCase shell variables.
- Bash tool on this host only works with `workdir` under `$HOME`; git/nix
  binaries may not be on the default PATH (use `/nix/store/...-git-…/bin/git`
  or invoke through the derivation).
- New files must be `git add`-ed (staged) before any flake eval/build — Nix's
  dirty-tree source excludes untracked files (see the snowfall-packages skill).
- Bun needs a writable/enumerable HOME inside derivations that exercise
  cache/lock paths: `export HOME=$TMPDIR` before `bun build`.
