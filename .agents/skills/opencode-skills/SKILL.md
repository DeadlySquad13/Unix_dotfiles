---
name: opencode-skills
description: This skill should be used when adding, wiring, or debugging an OpenCode skill in this Unix_dotfiles repository — choosing the repo's skillPaths mechanism vs direct HM skills option, the store-path/baseNameOf trap, openable directory layout, and verifying skill registration.
---

# Add an OpenCode skill

Use this skill when adding a new skill available in OpenCode sessions
(`SKILL.md` + optional assets the model may consult).

## Where OpenCode skills live

- **Repository-development skills** (instructions for agents *working on this
  repo*) live under `.agents/skills/<name>/SKILL.md`. They are not deployed
  into OpenCode config — they are consumed by the repo's agent runtime. See
  the house style in `.agents/skills/snowfall-modules/SKILL.md` (YAML
  frontmatter `name` + `description`, demonstrative sections, pitfalls).
- **Session skills** (available to OpenCode in normal sessions) are wired
  through the Home Manager module tree, below
  `modules/home/apps/ai-assistance/opencode/skills/<name>/`.

## Wiring session skills — two mechanics, know which one you're using

1. **Repo's own `skillPaths` mechanism** (`.../opencode/tools/shared.nix`
   `genAttrs'` on `skillPaths` → `baseNameOf` names). Use it for
   repository-authored skills placed alongside the module tree. **It cannot
   carry a Nix store path** — `baseNameOf` propagates the store-path context
   into the *attribute name*, and evaluation fails with
   `the string '<name>' is not allowed to refer to a store path`. Never route
   a derivation output through `skillPaths`.
2. **Direct Home Manager option** `programs.opencode.skills."<name>"` — the
   locked HM module (`modules/programs/opencode.nix`, home-manager rev
   `5bd3589390b431a63072868a90c0f24771ff4cbb`) accepts
   lines / inline path / **store-path string**; a string that is a store
   directory is treated as a skill directory and linked recursively.
   Use this when the skill ships inside a packaged plugin:
   ```nix
   programs.opencode.skills."ssh-remote-dev" = "${plugin}/share/skills/ssh-remote-dev";
   ```

## Authoring a new session skill in this repo

1. Create `modules/home/apps/ai-assistance/opencode/skills/<name>/SKILL.md`
   (frontmatter: `name`, `description` — description shapes when the model
   loads it, keep it outcome-oriented).
2. Wire through mechanism 1 (add the dir to the opencode module's
   `skillPaths`/shared config) — follow how existing sibling skills are
   registered in `modules/home/apps/ai-assistance/opencode/default.nix`.
3. Element checklist: every path expression in config is a *string* (never a
   derivation), skill dir holds only what the model needs, and the gate is
   temp/working if the skill references tools that require containers.

## Verify — do not trust a successful module eval alone

Home Manager skill values are lazy stores; inspect the materialized tree:

```sh
nix eval .#homeConfigurations."<user>@<host>".activationPackage.drvPath
nix build .#homeConfigurations."<user>@<host>".activationPackage
find result/home-files/.config/opencode/skill -maxdepth 2 -name SKILL.md
```

- The skill directory must be present as a symlink at
  `~/.config/opencode/skill/<name>`/ (OpenCode's base dir).
- `opencode debug config` shows the merged skill bank at runtime.
- If a skill name collides with an OpenCode-managed skill dir (e.g.
  `git-commit-…`), pick a distinct name; collisions surface at runtime, not eval.

## Counterexample worth remembering

A store-path-valued skill wired through `skillPaths` fails only *at eval of
the home config*, not at the package build. When a module's consumer fails
with a cryptic "string X is not allowed to refer to a store path" error,
audit whether any helper built from the value (`baseNameOf`, `toString`)
propagated context into an attr key.
