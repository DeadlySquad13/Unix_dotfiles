---
name: snowfall-modules
description: This skill should be used when adding, moving, importing, enabling, or debugging NixOS or Home Manager modules in this Unix_dotfiles repository. It explains the repository's Snowfall Lib discovery, module ownership, namespace options, and validation conventions.
---

# Work with Snowfall modules

Use this skill for module-layout or module-import changes. Read `README.md`,
especially "Automatic Importing and Exporting" and "Accessing Inputs and
Libs", before editing.

## Use repository discovery

- Put reusable NixOS modules below `modules/nixos/...`, Home Manager modules
  below `modules/home/...`, and Darwin modules below `modules/darwin/...`.
  Snowfall discovers every tree automatically, but each tree belongs to a
  separate module graph.
- Do not manually import an auto-discovered module from a system or home merely
  to make it available. A duplicate import declares its options twice.
- Import a module explicitly only when it is outside an auto-discovered tree or
  is intentionally local glue, for example a file below `systems/...` or
  `homes/...`.
- Put reusable library functions below `lib/<name>/default.nix`. Snowfall merges
  them into the repository library; use the exposed function through `lib`.
  Inspect an existing library function before assuming its exact attribute path.

## Keep platform layers separate

- Use `systems/...` to configure options declared by `modules/nixos/...`.
- Use `homes/...` to configure options declared by `modules/home/...`.
- Use `modules/darwin/...` and Darwin configurations for macOS equivalents.
- Do not set a Home Manager-only option from a NixOS system module, or a
  NixOS-only option from a standalone Home Manager configuration. They do not
  intersect unless NixOS embeds Home Manager through `home-manager.users`.
- When a system-owned runtime resource must be consumed by standalone Home
  Manager, pass its known runtime path through a repository namespace option in
  per-home glue rather than trying to read system `config` from Home Manager.

## Enable discovered modules deliberately

Snowfall makes discovered modules available by default; it does not mean every
module should affect every target. Wrap reusable modules in the repository
enable mechanism so a host/home chooses them explicitly:

```nix
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "general";
  name = "neovim";
}
{
  # Module behavior.
}
// {
  # User-facing options: config.${namespace}.<category>.<name>.*
  options.${namespace}.general.neovim = {
    exampleOption = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Example user-facing Neovim setting.";
    };
  };
}
```

- `mkIfEnabled` adds the enable option below
  `lib.${namespace}.modules.<category>.<name>.enable` and applies the body only
  when enabled.
- Categories can be nested; inspect the relevant module-enable tree, such as
  the development category, before setting a value.
- Use the same helper in subfiles that need the parent/module-enable contract.
  See `modules/home/apps/general/neovim/default.nix` and its imported files.
- Do not manually import an automatically discovered module to enable it; set
  its generated enable option in the appropriate home/system configuration.

## Classify options by ownership

- **Enable options:** let `mkIfEnabled` create
  `lib.${namespace}.modules.<category>.<name>.enable`.
- **User-facing module options:** define these under
  `config.${namespace}.<category>.<name>.<option>`. Set them in a `systems/...`
  or `homes/...` target. Example:

  ```nix
  ds-omega.development.docker.enableAlias = true;
  ```

  Consume them with a namespace cfg:

  ```nix
  cfg = config.${namespace}.development.docker;
  ```

  See `modules/home/apps/development/docker/default.nix`.
- **Internal coordination options:** use these only for data shared between
  submodules of one larger feature, such as
  `config.programs.opencode.mcpContainers`. Keep them distinct from
  user-facing inputs. They may be nested below a standard namespace for local
  coordination, but check for upstream/Home Manager option conflicts before
  adding one.
- Define reusable behavior and option contracts in `modules/`; put host- or
  user-specific values in local glue below `systems/...` or `homes/...`.
- Consume namespace inputs to form processed program/service configuration.
- Do not use processed configuration as an input required to construct that
  configuration. See `docs/adr/sops-opencode.md` for the secret-template
  example.

## Respect evaluation boundaries

- NixOS and standalone Home Manager are separate module graphs. A system module
  cannot set a Home Manager option unless Home Manager is embedded through
  `home-manager.users`.
- Define a SOPS secret/template at the layer that owns its runtime path. Pass a
  known runtime path through home glue when a system-owned template is consumed
  by standalone Home Manager.
- Avoid requesting an optional module argument such as `namespace` in a module
  evaluated by a context that does not provide it; this can recurse through
  `_module.args`. Use the repository's established fixed namespace pattern when
  necessary.

## Prove that configuration propagates

Successful evaluation does not prove a lazy Nix value was consumed. After an
evaluation or build, inspect the generated derivation/output and compare it to
the previous generation when changing options, imports, or wiring.

```sh
# Evaluate the exact Home Manager target.
nix eval .#homeConfigurations."<user>@<host>".activationPackage.drvPath

# Build its generation, then inspect what changed.
nix build .#homeConfigurations."<user>@<host>".activationPackage
nix-store --query --references result
git diff
```

- For generated configuration, locate and read the generated store file or its
  installed symlink. For example, inspect generated Compose YAML and confirm a
  newly set `env_file`, port, or command is actually present.
- Compare old and new derivation paths or use a derivation diff tool such as
  `nix-diff <old-drv> <new-drv>` when both are available. A changed source file
  with an unchanged relevant derivation often means the module was disabled,
  not imported, or the changed option was never forced.
- Build/evaluate the relevant system/image output as well as the Home Manager
  output when changing a cross-layer runtime path. A standalone Home Manager
  evaluation cannot prove a NixOS image includes its system-owned service or
  secret template.
- Prefer inspecting a narrow output over assuming that a successful top-level
  build evaluated all optional branches.

## Add or modify a module

1. Locate the owner and determine whether the change is reusable, system-local,
   or home-local.
2. Place the file in the corresponding tree.
3. Define options before consuming them; use `mkIfEnabled` for modules governed
   by the repository module-enable tree.
4. Add local glue imports only for files Snowfall does not discover.
5. Evaluate and build the exact target: `nix eval .#homeConfigurations."<user>@<host>".activationPackage.drvPath` for a Home Manager target, or the relevant system/image output for a NixOS target.
6. Inspect the generated output and derivation difference to prove the option
   propagated; do not stop at a successful build.
7. If an option is "already declared", remove the duplicate manual import.
