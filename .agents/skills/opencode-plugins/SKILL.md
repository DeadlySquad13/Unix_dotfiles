---
name: opencode-plugins
description: This skill should be used when installing, pinning, wiring, or debugging an OpenCode plugin in this Unix_dotfiles repository — the file:// bundle contract, git-pinned flake input, Nix package build without npm, module wiring (disabled by default), enablement per home, and diagnosing the startup-hang / ResolveMessage failure signature.
---

# Add an OpenCode plugin

Use this skill when a plugin should be **pre-installed via Nix and pinned via
git** so OpenCode never tries to download it at startup via npm/bun (the
user's network times out on npm). Reference implementation:
`packages/opencode-ssh-session/default.nix` +
`modules/home/apps/ai-assistance/opencode/ssh-session-plugin/`.

## The pinned-source pattern

1. Inspect the project locally first (its `README.md`, `package.json`, `src/`)
   to learn exports, runtime imports, and peer deps. Confirm the exact git
   rev you'll pin (`.git/packed-refs` / tags) and the remote.
2. Add a `flake = false` input pinned by rev in `flake.nix` (follow the
   `opencode-ssh-session` / `mcp-logseq` blocks):
   ```nix
   opencode-ssh-session = {
     flake = false;
     url = "github:<owner>/<repo>/<commit-rev>";
   };
   ```
   then `nix flake lock --update-input <input>` to pin `flake.lock`. Prove
   the fetch equals your local checkout with `nix flake prefetch` + `diff -r`
   before trusting it.

## Build a self-contained bundle (the `file://` contract)

OpenCode treats non-`file://` `plugin` entries as npm packages and installs
them via `bun` (BunProc) at startup — never add those. Entries starting with
`file://` are imported directly, **but the host does not resolve bare
specifiers for them**. Consequences:

- The build must keep **zero** bare specifiers in the bundle. Runtime deps
  (`@opencode-ai/plugin`, and transitively e.g. `zod`) must be vendored from
  pinned sources; see the `packaging-js-repos` skill for how, and how to
  verify (bare-import grep + timed offline import test).
- Never rely on the README's npm-install build pattern for `file://` use.
- Use `bun build src/index.ts --outdir dist --target bun` — OpenCode's
  runtime is Bun.
- Note the failure signature for future debugging: `ResolveMessage: Cannot
  find module '<spec>' from '<out>/dist/index.js'` repeated in the OpenCode
  log, and `bun -e 'import(...)'` hanging on "Resolving" (Bun's implicit
  registry install fallback).

## The module (separate, disabled by default)

Create `modules/home/apps/ai-assistance/opencode/<plugin-suffix>/default.nix`
with the repo's enable mechanism:

```nix
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ai-assistance.opencode";
  name = "<plugin-suffix>";
}
{
  plugin = pkgs.${namespace}.<package-name>;
  config.programs.opencode.settings.plugin =
    [ "file://${plugin}/dist/index.js" ];
  config.programs.opencode.skills."<skill>" = "${plugin}/share/skills/<skill>";
  config.programs.opencode.agents."<agent>" = ./agent/<agent>.md;
}
```

- `mkIfEnabled` makes it disabled by default; no other home is affected.
- Skill wiring must use the direct `programs.opencode.skills` option — the
  repo's `skillPaths` helper cannot carry store paths (see the
  `opencode-skills` skill).
- Load-time behavior: a plugin factory that returns hooks/tools is lazy at
  startup — no spawns, no network. If startup hangs, the bug is in the
  bundle/loader interaction, not the factory body.

## Enablement + validation

```sh
# In homes/<sys>/<user>@<host>/default.nix, inside lib.${namespace}.modules:
#   ai-assistance.opencode.<plugin-suffix> = enabled;

nix eval --impure --json .#homeConfigurations."ds13@salt".config.programs.opencode.settings.plugin
# → must show ["file:///nix/store/<hash>-<pkg>/dist/index.js"]

# Prove disabled-by-default on an unrelated home: the same eval must *not*
# contain the file:// entry (or unset entirely), and no skill/agent must leak.
```

Full activation builds may fail on pre-existing host limitations (e.g.
missing per-user runtime paths of another home) — use targeted `nix eval` on
the exact consumer options, then finish validation on the real host with
`make switch` and confirm: `opencode.json` plugin entry points at the *new*
store path, and there are no ResolveMessage errors in
`~/.local/share/opencode/log/<latest>.log`.

## Debug checklist for "opencode startup takes forever"

1. `tail -f ~/.local/share/opencode/log/$(ls -t ~/.local/share/opencode/log | head -1)` — find the last non-GET line before the stall.
2. Confirm the exact `file://` store path in `~/.config/opencode/opencode.json` and verify the file exists on that machine (`ls` it) — a stale config may point at a store path from before the last rebuild.
3. `grep -oE 'from "[^."]+"' <that file>/dist/index.js | sort -u` — must list only builtins/relative. A bare `@opencode-ai/...` import = vendoring fix needed (not `--external`).
4. `cd $(mktemp -d) && timeout 10 bun -e 'await import("file://<path>"); console.log("ok")'` — kitchen-sink repro without OpenCode.
