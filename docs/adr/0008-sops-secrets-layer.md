# ADR 0008: SOPS secret and template ownership across system and home layers

- Status: Accepted
- Date: 2026-10-26
- Supersedes: the generic SOPS decisions formerly combined in
  [sops-opencode.md](sops-opencode.md)
- Related: [ADR 0001](0001-runtime-home-bridge.md),
  [ADR 0009](0009-sops-opencode.md)
- Scope: system and Home Manager SOPS ownership: `sops.secrets`,
  `sops.templates`, placeholders, runtime rendered paths, permissions,
  out-of-store symlinks, cross-layer consumption, and Snowfall module
  boundaries.

This ADR records the generic layered-SOPS contract and the `sops-npmjs` domain
module. It is the home for base SOPS ownership and for the npm/`~/.npmrc`
domain. The OpenCode-specific application is
[ADR 0009](0009-sops-opencode.md). Apply this ADR to any application or service
that needs a secret, an environment file, or a generated configuration file; do
not couple the generic pattern to a particular client.

The accepted ownership split is:

- base `sops` = base settings only (sops-nix import, vault, age key file);
- `sops-opencode` = OpenCode-specific secrets and templates;
- `sops-npmjs` = npm secrets and the rendered `npmrc` template.

Enabling a domain module enables only that domain's secrets. Enabling base
`sops` must not declare npm or OpenCode secrets.

## TDLR

Generic layered structure:

1. System
    1. Define base SOPS behavior:
       `modules/nixos/ecosystem/sops/default.nix` (sops-nix import, default
       vault, and age key-file default).
    2. Declare npm secrets and templates in the `sops-npmjs` domain module:
       `modules/nixos/ecosystem/sops-npmjs/default.nix`, not the base module
       and not `sops-opencode`.
    3. Wire the rendered path into the consuming program through namespace or
       host glue. A consumer must not reach into another module's template
       ownership.
2. Per-system overrides
    1. Override `age.keyFile` according to deployment volumes, and set secret
       or template `owner`/`group`/`mode` and runtime paths in the system tree.
3. Home Manager
    1. Define base Home Manager SOPS behavior:
       `modules/home/apps/ecosystem/sops/default.nix`.
    2. Declare npm secrets and templates in
       `modules/home/apps/ecosystem/sops-npmjs/default.nix`.
    3. Consume a nullable runtime path from the program module. The narrower
       level has priority; an explicit per-host override wins over an implicit
       same-layer template.

## Context

A secret-backed file is created by SOPS at either the NixOS or Home Manager
layer, while a program module turns repository inputs into processed
configuration. These are different ownership and evaluation layers. Treating
them as one option namespace caused a self-reference/undefined-value failure
when `cfg` was used both for processed configuration and for an external input.
The same split applies to every consumer; [ADR 0009](0009-sops-opencode.md)
records the OpenCode instance of this pattern.

## Decision

SOPS definitions, deployment glue, and program configuration are separate
responsibilities.

### Layer ownership

1. The base system/Home Manager SOPS module imports sops-nix, selects the vault
   (`sops.defaultSopsFile` or the repository equivalent), and establishes the
   age key-file default and common policy.
2. A reusable application or consumer module declares its own
   `config.sops.secrets` keys and `config.sops.templates`, uses
   `config.sops.placeholder.<name>` in template content, and exposes the
   path/options that other modules consume.
3. Per-system or per-home overlays own deployment facts: age `keyFile`, secret
   and template `owner`, `group`, `mode`, path-related values, and the runtime
   path wiring. Keep machine-specific filesystem, service, and container
   details out of the reusable module.

Allow narrower configuration layers to override broader defaults without
duplicating declarations. The reusable module owns the secret interface; the
overlay owns deployment facts.

`modules/nixos/ecosystem/sops-opencode/default.nix` is not an npm owner.
npm credentials such as `npmjs_auth_token` and the `npmrc` template belong to
the `sops-npmjs` domain module at the same layer, because OpenCode neither
declares nor consumes them. The base `sops` module must not declare either:
it owns only base settings.

Domain modules are intentionally separate:

| Module | Owns |
| --- | --- |
| `modules/{nixos,home}/.../sops` | base settings only |
| `modules/{nixos,home}/.../sops-opencode` | OpenCode secrets/templates |
| `modules/{nixos,home}/.../sops-npmjs` | npm secret and `npmrc` template |

A host enables the domain module it needs. Enabling base `sops` alone creates
no domain secrets; enabling `sops-npmjs` enables only npm.

### Secrets, templates, and placeholders

Declare a vault key and reference it through a placeholder:

```nix
sops.secrets.service_api_token = {
  owner = cfg.user;
  group = cfg.group;
  mode = "0400";
};

sops.templates."service.env" = {
  owner = cfg.user;
  group = cfg.group;
  mode = "0400";
  content = ''
    SERVICE_API_TOKEN=${config.sops.placeholder.service_api_token}
  '';
};
```

- Use `config.sops.secrets.<name>.path` when a program consumes one extracted
  secret file.
- Use `config.sops.placeholder.<name>` only inside a sops-nix template.
- Use `config.sops.templates.<name>.path` when a program consumes the generated
  template.
- Use quoted attribute syntax for names containing punctuation:
  `config.sops.templates."service.env".path`.

Keep encrypted values in the SOPS vault. Commit declarations, key names,
template boilerplate, and placeholders only; never put plaintext values in Nix,
generated configuration, examples, logs, shell history, or the Git repository.
Edit the vault as a separate, deliberate operation.

### Runtime rendered paths and out-of-store symlinks

Treat `config.sops.templates.<name>.path` as a runtime/out-of-store path.
sops-nix templates are not guaranteed to exist in the Nix store during
evaluation or build. Do not force a build-time read of the path, for example
with `builtins.readFile`.

When a program needs a stable home path, symlink to the runtime path without
copying the decrypted file into the store:

```nix
home.file.".npmrc".source =
  config.lib.file.mkOutOfStoreSymlink npmrcSource;
```

A plain store copy would place decrypted content in the Nix store. A derivation
that genuinely requires a secret during build needs a separately reviewed,
explicit mechanism and must not silently turn a runtime secret into a store
input.

### Runtime permissions

Choose the extracted file's `owner`, `group`, `mode`, and destination path for
the process that opens it at runtime. Verify that the parent directory is
traversable and that activation does not place the file in an inaccessible
location.

For rootless services and containers, use the effective service UID and GID,
not root or a host-only group; account for UID/GID mapping, bind-mount paths,
container user configuration, and whether the application needs a file or an
environment variable. Prefer least privilege (`0400` for a single user, `0440`
when a group must read) and avoid world-readable modes. Never print the file
while diagnosing access.

### Cross-layer consumption

Do not make a reusable module assume that a template exists at every
configuration layer. Expose a nullable or otherwise configurable runtime path
when another module consumes the generated file:

```nix
options.myService.environmentFile = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = "Runtime SOPS-generated environment file.";
};
```

Set that option in the layer that declares or selects the template, commonly
with `config.sops.templates."service.env".path`, and wire the consumer
conditionally only when the option is non-null. This keeps application modules
reusable when a service uses another secret mechanism or no template.

A system-owned template consumed by standalone Home Manager must be passed as a
known runtime path through home glue. Home Manager is a separate module graph
and must not read system `config` directly.

When both a same-layer template and an explicit per-host runtime path can
exist, the explicit narrow value wins. The implemented precedence in
`modules/home/apps/development/nodejs/default.nix` is:

```nix
npmrcSource =
  if cfg.npmrcSource != null
  then cfg.npmrcSource
  else if homeNpmrcTemplate != null
  then homeNpmrcTemplate.path
  else null;
```

The `sops-npmjs` home module sets `nodejs.npmrcSource` explicitly to either
`config.sops.templates."npmrc".path` (home owns SOPS) or the system-rendered
`systemRuntimePath` (container home). The explicit value therefore wins over
the implicit `homeNpmrcTemplate` lookup. Do not auto-wire a token into every
Node-enabled home: the domain module or its host glue is the opt-in.

### Snowfall module boundaries

- One owning module per concern.
- Wrap reusable modules with `lib.${namespace}.mkIfEnabled { category; name; }`
  and set their enable options from `systems/...` or `homes/...`.
- Define user-facing module options under
  `config.${namespace}.<category>.<name>.*`, and keep internal coordination
  options separate.
- Put host- or user-specific values in local glue below `systems/...` or
  `homes/...`.
- Do not manually import an auto-discovered module just to enable it.
- Do not let a consumer declare, duplicate, or reach into another module's
  template ownership. The owner declares the template; the consumer receives a
  path.
- Do not use processed configuration as an input required to construct that
  configuration. A `cfg` bound to processed output must never provide the
  external value used to build it.
- Prefer narrow per-host overrides over broad duplication.

### Generic consumer example: npm and `~/.npmrc`

npm credentials are a Node/npm concern, not an OpenCode concern.
`npmjs_auth_token` and the `npmrc` template are owned by the `sops-npmjs`
domain module at the layer that materialises them. The system-level template
exists because container homes do not evaluate Home Manager SOPS and instead
point `~/.npmrc` at the system-rendered runtime file.

Implemented system declaration
(`modules/nixos/ecosystem/sops-npmjs/default.nix`, options simplified):

```nix
sops.secrets.npmjs_auth_token = {
  owner = cfg.username;
  group = cfg.group;
  mode = cfg.mode;
};

sops.templates."npmrc" = {
  owner = cfg.username;
  group = cfg.group;
  mode = cfg.mode;
  path = cfg.runtimePath;
  content = ''
    registry=https://registry.yarnpkg.com
    //registry.npmjs.org/:_authToken=${config.sops.placeholder.npmjs_auth_token}
  '';
};
```

Home Manager's sops-nix template module has no `owner`/`group` options, so the
home `sops-npmjs` module sets `mode = "0400"` and relies on activation running
as the home user.

The system-to-home mapping is a literal runtime path: system glue sets
`ds-omega.ecosystem.sops-npmjs.runtimePath`, and the darkGreen home glue sets
`ds-omega.ecosystem.sops-npmjs.systemRuntimePath` to the same
`/run/secrets/rendered/npmrc`, because Home Manager is a separate module graph.

The consuming Home Manager module keeps the runtime path configurable and
symlinks out of store:

```nix
home.file.".npmrc" =
  if npmrcSource != null
  then {
    source = config.lib.file.mkOutOfStoreSymlink npmrcSource;
  }
  else {
    text = ''
      registry=https://registry.yarnpkg.com
    '';
  };
```

The registry is the Yarn mirror because npm/npx hang against the official
registry on this network; only a single `registry` is set because npm has no
ordered multi-registry fallback.

The former `npmjs_auth_token` and `npmrc` declarations in
`modules/nixos/ecosystem/sops-opencode/default.nix` were a boundary violation.
OpenCode does not consume them. They now live in the `sops-npmjs` domain
module; the base `sops` modules do not declare either.

### Dependency flow

The generic flow is the same at each layer:

```text
domain SOPS module (`sops-npmjs`, `sops-opencode`) declares
sops.secrets / sops.templates
  -> config.sops.templates."<name>".path or config.sops.secrets."<name>".path
  -> per-home or per-system namespace glue, or the consumer's nullable option
  -> consumer program reads the runtime path
  -> processed program/service configuration
```

The namespace option is user-facing input. `cfg` and the processed
program/service configuration are output. The latter must never provide the
former.

The OpenCode-specific instance of this flow is recorded in
[ADR 0009](0009-sops-opencode.md); the npm instance is `sops-npmjs`.

## Implementation rules

- Keep base SOPS modules limited to import, vault, key-file, and common policy;
  do not hide consumer secrets in them when the concern has its own owner.
- Put domain secrets in their domain module: base `sops` = base settings,
  `sops-opencode` = OpenCode, `sops-npmjs` = npm.
- Enabling a domain module enables only that domain's secrets; enabling base
  `sops` must not declare npm or OpenCode secrets.
- Keep the SOPS definition enabled at the same layer as the glue that reads its
  template or secret path.
- Keep per-home values in the home tree and per-system values in the system
  tree.
- Keep program `cfg` bound only to processed program configuration.
- Preserve the repository namespace boundary instead of adding an external
  input to an upstream program option space.
- Treat template paths as runtime paths; never read them at build time.
- Set least-privilege permissions and verify them as the runtime user.
- Let an explicit narrow runtime-path override win over an implicit same-layer
  template.
- Do not declare a credential in the wrong module: do not put npm in
  `sops-opencode` or base `sops`, and do not put OpenCode keys in `sops-npmjs`.

## Troubleshooting

### Missing template path

Confirm that the matching SOPS definition is enabled at the same layer as the
glue module. Inspect the exact `config.sops.templates."<name>".path` reference
and verify that the NixOS or Home Manager template exists before wiring it into
the namespace option. If the path is absent, first fix layer
inclusion/ownership rather than changing the consumer to manufacture a
fallback.

### Self-reference or undefined `cfg`

Verify that the consumer's `cfg` resolves only to its processed program
configuration. Supply the external path from per-home or per-system namespace
glue, or from a nullable consumer option. Do not read it back from processed
configuration or from `cfg` itself. For the OpenCode case see
[ADR 0009](0009-sops-opencode.md).

### Wrong ownership or evaluation layer

Check whether the consumer is a Home Manager or NixOS module, then confirm that
its SOPS template and glue are created in that same layer. A system-owned
template consumed by standalone Home Manager must be passed as a runtime path
through home glue.

### Runtime file inaccessible

Check, in order: selected vault and age key-file path; decryption identity and
file readability; exact secret key names; template placeholder spelling;
activation/service logs; runtime path existence; parent-directory traversal;
UID/GID and mode; and container bind mounts. Inspect metadata only; do not
`cat`, `env`, or otherwise print secret values.

### Secret material in the Nix store

If decrypted content appears in a derivation, check for a build-time read of a
runtime path (`builtins.readFile`, `builtins.path`, or a plain store copy).
Replace it with an out-of-store symlink or a runtime reference. Confirm that a
build does not contain secret text before publishing or committing it.

## Migration / follow-up

Status: implemented on 2026-10-26. The migration steps were:

1. Move `npmjs_auth_token` and the system `npmrc` template out of
   `modules/nixos/ecosystem/sops-opencode/default.nix` into the new system
   `sops-npmjs` domain module
   (`modules/nixos/ecosystem/sops-npmjs/default.nix`).
2. Move `npmjs_auth_token` and `npmrc` out of the base home SOPS module into
   `modules/home/apps/ecosystem/sops-npmjs/default.nix`; keep OpenCode-specific
   keys and `opencode-auth.json` in the home `sops-opencode` module.
3. Make explicit `npmrcSource` win over the implicit home template in
   `modules/home/apps/development/nodejs/default.nix`.
4. Set least-privilege permissions: system secret/template
   `owner`/`group`/`mode` are options; the home template uses `mode = "0400"`
   because Home Manager's sops-nix template module has no owner/group options.
5. Rewrite comments that called npm the "system-level counterpart" of the
   OpenCode module, and remove npm from `sops-opencode`.

Host glue now owns deployment facts: system glue under
`systems/.../apps/ecosystem/sops-npmjs/` sets `username`/`group`/`mode`/
`runtimePath`; darkGreen home glue sets `systemRuntimePath` to the same literal
`/run/secrets/rendered/npmrc`. The base `sops` modules declare no npm artifacts.

## Synchronization

Update this ADR when changing SOPS layering, secret/template ownership, the
runtime-path contract, permission policy, or cross-layer consumption. Keep
`AGENTS.md` limited to the generic rules and link here. OpenCode-specific
changes belong in [ADR 0009](0009-sops-opencode.md); npm changes belong to the
`sops-npmjs` domain module described here.
