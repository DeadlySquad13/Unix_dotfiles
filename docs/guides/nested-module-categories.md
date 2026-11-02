# Nested module categories

How a dotted `category` maps to the module tree, how enablement inherits, and
when to nest a category instead of keeping it flat. `development.nix` is the
canonical example; `ecosystem.sops` is the concrete SOPS case.

## What a dotted category means

Snowfall discovers a module from its directory, and `mkIfEnabled` in
`lib/modules/default.nix` records the same path as a dotted `category` plus a
`name`:

| Module | File | `category` | `name` |
| --- | --- | --- | --- |
| Alejandra | `modules/home/apps/development/nix/alejandra/default.nix` | `development.nix` | `alejandra` |
| SOPS base | `modules/home/apps/ecosystem/sops/default.nix` | `ecosystem` | `sops` |
| OpenCode SOPS | `modules/home/apps/ecosystem/sops/opencode/default.nix` | `ecosystem.sops` | `opencode` |
| npm SOPS | `modules/home/apps/ecosystem/sops/npmjs/default.nix` | `ecosystem.sops` | `npmjs` |

Each dot is one directory level between `apps/` and the module's `name`
directory. The base SOPS module is the pivot: its category stops at
`ecosystem`, so `ecosystem.sops` is both its own module pickup and the parent
node for the two child domains.

## Enablement inheritance

`mkIfEnabled` reads the host-set enable tree at
`lib.<namespace>.modules.<category parts>.<name>.enable`:

```nix
lib.ds-omega.modules = {
  ecosystem = {
    sops = {
      enable = true;          # base module + default gate for children
      opencode.enable = true; # explicit child opt-in
    };
  };
};
```

The gate is computed from the deepest dotted category:

```nix
category-cfg = attrByPath ["ecosystem" "sops"] {} modules-cfg;
category-enabled = category-cfg ? enable && category-cfg.enable;
module-enabled = if module-cfg ? enable then module-cfg.enable else category-enabled;
```

Consequences:

- A category `enable = false` disables children that have no explicit
  `enable`.
- A child with `enable = true` opts back in even when the owning category is
  off (the `cli-utility` / `bash` case).
- A child with `enable = false` stays off even when the owning category is on.
- Only the owning (deepest) category node is consulted. A switch above it,
  such as `ecosystem.enable`, does not override a deeper
  `ecosystem.sops.enable`; the `mkIfEnabled` TODO records this limitation.

Concrete outcomes:

- `homes/x86_64-linux/ds13@salt/default.nix` sets `sops.opencode = enabled;`.
  The base SOPS module is on through `ecosystem.enable`, and the OpenCode child
  opts in explicitly; npm is not enabled.
- `homes/x86_64-linux/ds13@cake/default.nix` sets `sops = disabled;`. That
  disables base SOPS and both child domains without listing each child, which
  removes the sops-nix "No key source configured" assertion.
- The darkGreen homes set `sops.npmjs = enabled;` and supply
  `ds-omega.ecosystem.sops.npmjs.systemRuntimePath`; the base module stays off
  because those homes consume system-rendered SOPS.

## Option paths

User-facing options follow the same nesting as the module:

```nix
options.ds-omega.ecosystem.sops.npmjs.systemRuntimePath =
  lib.mkOption { ... };
```

Read and write the enable tree at `lib.ds-omega.modules.ecosystem.sops.npmjs`,
and ordinary module options at `ds-omega.ecosystem.sops.npmjs.*`.

`mkIfEnabled` also declares `<namespace>.<category>.<name>.enable`. Because
`category` is interpolated as one string, a dotted value becomes a single
quoted key (`ds-omega."ecosystem.sops".npmjs.enable`), not a nested path. Hosts
should keep enabling through `lib.<namespace>.modules`, which is the tree the
gate actually reads.

## When to nest vs keep flat

Use a nested category when:

- Two or more child modules are domains of one concern and should share a
  single gate (OpenCode and npm under base SOPS).
- The parent also exists as a module, so its `enable` is a meaningful default
  for the children.
- You want the directory tree to mirror the ownership hierarchy.

Keep a flat category when:

- The module stands alone and has no sibling domains.
- The module is a peer of existing top-level categories; adding a parent
  directory would imply a shared gate that does not exist.
- The module kind differs. NixOS `modules/nixos/ecosystem/sops-opencode` and
  `sops-npmjs` stayed flat while Home Manager nested its SOPS domains. Do not
  assume the trees mirror each other.

## Migration note: flat to nested

The `sops-npmjs` / `sops-opencode` to `ecosystem.sops.*` move is the concrete
case. For npm (replace `npmjs` with `opencode` for the OpenCode child):

| Before | After |
| --- | --- |
| `modules/home/apps/ecosystem/sops-npmjs/default.nix` | `modules/home/apps/ecosystem/sops/npmjs/default.nix` |
| `category = "ecosystem"; name = "sops-npmjs"` | `category = "ecosystem.sops"; name = "npmjs"` |
| `lib.ds-omega.modules.ecosystem.sops-npmjs.enable` | `lib.ds-omega.modules.ecosystem.sops.npmjs.enable` |
| `ds-omega.ecosystem.sops-npmjs.systemRuntimePath` | `ds-omega.ecosystem.sops.npmjs.systemRuntimePath` |

Steps:

1. Move the module directory under the parent category directory.
2. Change `category` to the dotted parent path and shorten `name` to the final
   directory.
3. Rename custom options and update host glue to the nested option path.
4. Check inheritance: a disabled owning category now disables children with no
   explicit `enable`, so remove redundant child disables.
5. Keep host-local glue imports at their existing paths when only the module
   category changed. In this repository the darkGreen home glue still lives at
   `homes/.../apps/ecosystem/sops-npmjs/` and
   `homes/.../apps/ecosystem/sops-opencode/`; the rename applies to the module
   `category`/`name` and option paths, not to every directory name.
6. Do not move NixOS modules for symmetry.
   `modules/nixos/ecosystem/sops-opencode` and `sops-npmjs` remain flat, and
   their options still use `ds-omega.ecosystem.sops-npmjs.*` and
   `ds-omega.ecosystem.sops-opencode.*`.

## Validation

- `make modules-check` builds `checks/mkIfEnabled`, which covers nested
  category enable/disable and child override cases.
- `make modules-home HOST=<user>@<host>` dumps the enable tree. Inspect one
  branch with:

  ```sh
  make modules-home-category HOST=<user>@<host> MODULE_CATEGORY=ecosystem.sops
  ```

  Use `modules-system-category` for the NixOS tree.
- Build the affected host/home and inspect the generated SOPS template paths
  and permissions.

## See also

- `docs/adr/0008-sops-secrets-layer.md` — generic SOPS layering.
- `docs/adr/0009-sops-opencode.md` — OpenCode instance.
- `lib/modules/default.nix` — `mkIfEnabled` implementation.
- `checks/mkIfEnabled/default.nix` — enablement cases.
