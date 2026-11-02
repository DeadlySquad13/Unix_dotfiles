# ADR 0009: SOPS delivery to OpenCode MCP configuration

- Status: Accepted
- Date: 2026-10-26
- Supersedes: the OpenCode-specific decisions formerly combined in
  [sops-opencode.md](sops-opencode.md)
- Related: [ADR 0001](0001-runtime-home-bridge.md),
  [ADR 0008](0008-sops-secrets-layer.md)
- Scope: SOPS secret/template delivery to OpenCode MCP configuration, the
  OpenCode SOPS domain (NixOS `sops-opencode`, Home Manager
  `ecosystem.sops.opencode`), its `logseq-mcp.env` and `opencode-auth.json`
  templates, OpenCode integration, and host glue that references the rendered
  paths.

This ADR records the OpenCode-specific form of the generic layered options
guidance in `AGENTS.md` and the generic SOPS contract in
[ADR 0008](0008-sops-secrets-layer.md). Keep SOPS definitions, layer-specific
glue, and processed OpenCode configuration distinct. npm/`.npmrc` ownership is
in the separate npm domain documented in ADR 0008. The OpenCode domain owns
only OpenCode-specific secrets and templates. Base `sops` owns base settings
only.

## TDLR

Layered structure:

1. System
    1. Define base Sops system settings: ../../modules/nixos/ecosystem/sops/default.nix
    2. Define Opencode specific Sops settings: ../../modules/nixos/ecosystem/sops-opencode/default.nix
        - define secret,
        - define template.
    3. Tie into opencode config: ../../modules/nixos/ai-assistance/opencode/default.nix
        - by default, symlink a home-manager file to the template;
        - when `ds-omega.ai-assistance.opencode.authPath` is set, skip that
          `home.file` and let the given path own auth (see "`home.file` auth must
          not shadow the runtime-home-bridge symlink" below).
2. Per-system overrides
    1. Override keyFile according to our docker volumes, set
       `ds-omega.ai-assistance.opencode` settings for system layer module,
       including `authPath` pointing at the bind-mounted opencode share:
    ../../systems/x86_64-docker/darkGreen-tangerineDream-green/apps/ecosystem/sops-opencode/default.nix
3. HomeManager
    1. Define base sops settings: ../../modules/home/apps/ecosystem/sops/default.nix
    2. Define nested OpenCode sops settings:
       ../../modules/home/apps/ecosystem/sops/opencode/default.nix
       (`category = "ecosystem.sops"; name = "opencode";`)
    3. Define opencode settings:
       ../../modules/home/apps/ai-assistance/opencode/default.nix
       - takes into account that API keys can be defined by sops on any of the
         levels. The narrower level, the more priority it has.

The same base-vs-domain split applies at both layers: base `sops` = base
settings only; the OpenCode domain = OpenCode secrets/templates; the npm
domain = npm secrets/templates. In NixOS the domains are `sops-opencode` and
`sops-npmjs`; in Home Manager they are the nested children
`ecosystem.sops.opencode` and `ecosystem.sops.npmjs`. Enabling a domain module
enables only that domain's secrets.

## Context

The MCP configuration needs a secret-backed environment-file path. The path is
created by SOPS at either the NixOS or Home Manager layer, while the OpenCode
module turns repository inputs into processed MCP container configuration. These
are different ownership and evaluation layers. Treating them as one option
namespace caused a self-reference/undefined-value failure when `cfg` was used
both for processed configuration and for an external input.

## Decision

### OpenCode boundary

`modules/home/apps/ai-assistance/opencode/mcp.nix` defines MCP server
configuration and consumes external namespace inputs, including
`logseqEnvironmentFile`.

Within `mcp.nix`, `cfg` means
`config.programs.opencode.mcpContainers`, the processed/generated OpenCode
program configuration. It must not provide `logseqEnvironmentFile` or any
other external input. Never make `programs.opencode.mcpContainers` provide the
namespace value used to construct it.

The external value is a repository-level, user-facing setting. Declare it in
the repository namespace, for example:

```nix
${namespace}.ai-assistance.opencode.mcp.logseqEnvironmentFile =
  config.sops.templates."logseq-mcp.env".path;
```

Do not put this input under `programs.opencode...`; that namespace belongs to
Home Manager's processed OpenCode options and risks collisions with its option
space.

### `home.file` auth must not shadow the runtime-home-bridge symlink

`auth.json` cannot have two owners when `~/.local/share/opencode` is a canonical
symlink managed by `services.runtime-home-bridge`. Home Manager materialises a
real directory for any managed child file, so declaring
`home.file.".local/share/opencode/auth.json"` clobbers the bridge's symlink to
the bind-mounted share (`/usr/local/<spice>-/<system>/_share/opencode`). OpenCode
then writes to an image-local directory, losing its session database on every
container start; the next boot also fails on the now non-symlink target.

`ds-omega.ai-assistance.opencode.authPath` therefore selects the owner. `null`
(default, e.g. a real machine) keeps the `home.file` symlink to
`/run/secrets/rendered/opencode-auth.json`; when set (e.g. a container) the
module omits `home.file` and the per-system glue exposes the template at that
path via `sops.templates."opencode-auth.json".path`, inside the bridged share.

See `0001-runtime-home-bridge.md`; layers running before or alongside the bridge
must not pre-create its canonical paths.

### SOPS definitions and layer-specific glue

SOPS definitions and the modules that pass their generated paths to OpenCode
are separate responsibilities.

The OpenCode domain (`sops-opencode` in NixOS, `ecosystem.sops.opencode` in
Home Manager) owns only OpenCode-specific keys and templates. The current
OpenCode-owned set is `opencode_go_api_key`, `cheap_vibe_code_api_key`,
`codexapi_api_key`, `logseq_api_token`, `logseq-mcp.env`, and
`opencode-auth.json`. npm credentials such as `npmjs_auth_token` and the
`npmrc` template are not OpenCode concerns and live in the npm domain module
(ADR 0008), not base `sops`. Their former placement in
`modules/nixos/ecosystem/sops-opencode/default.nix` was a boundary violation
that the migration below corrected.

#### NixOS system layer

1. Base SOPS behavior is defined in
   `modules/nixos/ecosystem/sops/default.nix`.
2. The NixOS `sops-opencode` module defines the secret and
   `logseq-mcp.env` template at the system layer.
3. Per-system glue belongs in the system tree, including
   `systems/x86_64-docker/darkGreen-tangerineDream/apps/ecosystem/sops-opencode/default.nix`
   and its `tangerineDream-green` counterpart. It sets the repository namespace
   OpenCode input from
   `config.sops.templates."logseq-mcp.env".path`.

The NixOS `sops-opencode` module must not declare `npmjs_auth_token` or the
`npmrc` template. Those belong to the system `sops-npmjs` domain module.

#### Home Manager layer

1. Base Home Manager SOPS behavior is defined in
   `modules/home/apps/ecosystem/sops/default.nix`
   (`category = "ecosystem"; name = "sops";`).
2. `modules/home/apps/ecosystem/sops/opencode/default.nix` defines the home
   layer's secret and `logseq-mcp.env` template as a nested child
   (`category = "ecosystem.sops"; name = "opencode";`).
3. Per-home glue belongs in the home tree. For example,
   `homes/x86_64-linux/ds13@salt/apps/ecosystem/sops-opencode/default.nix`
   sets the namespace input from the Home Manager template path. The host-glue
   directory keeps its original name; only the module `category`/`name` and
   option paths moved.

The home base SOPS module owns base settings only. OpenCode-specific keys
(`opencode_go_api_key`, `cheap_vibe_code_api_key`, `codexapi_api_key`) and the
`opencode-auth.json` template belong in the home OpenCode child
(`ecosystem.sops.opencode`), not in
`modules/home/apps/ecosystem/sops/default.nix`. npm keys and `npmrc` belong in
the home npm child (`ecosystem.sops.npmjs`). This follow-up correction is
implemented.

The OpenCode domain intentionally exists in both NixOS and Home Manager: as
`sops-opencode` in NixOS and as `ecosystem.sops.opencode` in Home Manager.
Each layer creates its own secret/template because its corresponding glue and
consumer live at that layer; neither definition is a duplicate substitute for
the other.

The nested child inherits the `ecosystem.sops.enable` gate of the base module.
A home that disables the base category disables OpenCode unless the child has
an explicit `enable = true`; `homes/x86_64-linux/ds13@salt/default.nix` opts
in with `sops.opencode = enabled;`. The same rule applies to
`ecosystem.sops.npmjs` in the darkGreen homes. See
`docs/guides/nested-module-categories.md`.

Tangerine Dream has a small intentional abstraction between the system module
and `sops-opencode`. It factors repeated system-specific SOPS behavior,
especially `username = systemBaseName`, so secret and template ownership
follows the system username. Treat this as deliberate abstraction, not
accidental duplication.

## Dependency flow

The flow is the same at each layer:

```text
OpenCode SOPS definition at the owning layer
(NixOS `sops-opencode`, Home Manager `ecosystem.sops.opencode`)
  -> config.sops.templates."logseq-mcp.env".path
  -> per-home or per-system namespace glue
  -> opencode mcp.nix consumes the namespace input
  -> programs.opencode.mcpContainers / generated Compose
```

The namespace option is user-facing input. `cfg` and
`programs.opencode.mcpContainers` are processed output. The latter must never
provide the former. npm is not part of this flow; see ADR 0008.

## Implementation rules

- Keep the SOPS definition enabled at the same layer as the glue that reads
  its template path.
- Keep per-home values in the home tree and per-system values in the system
  tree.
- Keep `cfg` in `mcp.nix` bound only to
  `config.programs.opencode.mcpContainers`.
- Preserve the repository namespace boundary instead of adding an external
  input to Home Manager's `programs.opencode` option space.
- Keep the OpenCode module limited to OpenCode secret keys and templates.
- Do not add npm credentials such as `npmjs_auth_token` or `npmrc` to the
  OpenCode module, and do not declare the same key/template in both the npm
  and OpenCode modules.
- Keep base `sops` = base settings, OpenCode domain = OpenCode, and npm
  domain = npm; enabling one domain must not declare another's secrets.
- In Home Manager, respect the nested category: `ecosystem.sops.opencode` is
  gated by `ecosystem.sops.enable` unless it has an explicit `enable`.
- Keep the `authPath` null/set contract intact; it selects which layer owns
  `auth.json`.

## Troubleshooting

### Missing template path

Confirm that the matching SOPS definition is enabled at the same layer as the
glue module. Inspect the exact
`config.sops.templates."logseq-mcp.env".path` reference and verify that the
NixOS or Home Manager template exists before wiring it into the namespace
option. If the path is absent, first fix layer inclusion/ownership rather than
changing `mcp.nix` to manufacture a fallback.

### Self-reference or undefined `cfg`

Verify that `cfg` in
`modules/home/apps/ai-assistance/opencode/mcp.nix` resolves to
`config.programs.opencode.mcpContainers`. Supply `logseqEnvironmentFile` from
per-home or per-system namespace glue. Do not read it back from
`programs.opencode.mcpContainers` or from `cfg` itself.

### Wrong ownership or evaluation layer

Check whether the consumer is a Home Manager or NixOS module, then confirm
that its SOPS template and glue are created in that same layer. For Tangerine
Dream, retain the intentional username abstraction and verify that
`systemBaseName` produces the expected owner.

### Generic credential declared in the OpenCode module

If a key or template is not consumed by OpenCode (for example
`npmjs_auth_token`/`npmrc`), move it to its domain module. npm belongs to the
npm domain (ADR 0008), not to base `sops` and not to the OpenCode module
(`sops-opencode` in NixOS, `ecosystem.sops.opencode` in Home Manager). Do not
add a second declaration; the npm and OpenCode modules must not both
materialise the same key/template.

## Migration / follow-up

Status: implemented on 2026-10-26; nested-category move implemented on
2026-11-02. The OpenCode-side migration steps were:

1. Remove `npmjs_auth_token` and the `npmrc` template from
   `modules/nixos/ecosystem/sops-opencode/default.nix`; the system
   `sops-npmjs` domain module now owns them (ADR 0008).
2. Move `opencode_go_api_key`, `cheap_vibe_code_api_key`,
   `codexapi_api_key`, and the `opencode-auth.json` template from
   `modules/home/apps/ecosystem/sops/default.nix` into
   `modules/home/apps/ecosystem/sops/opencode/default.nix`.
3. Do not change `logseq-mcp.env` ownership, the `authPath` null/set
   behavior, or the host glue paths while performing the moves.
4. Re-evaluate the exact NixOS systems and Home Manager profiles and inspect
   the generated template paths and permissions.
5. Move the home OpenCode module under the base category:
   `category = "ecosystem.sops"; name = "opencode";` at
   `modules/home/apps/ecosystem/sops/opencode/default.nix`. The NixOS module
   remains `modules/nixos/ecosystem/sops-opencode/default.nix`.

The npm split is complete as well: the system `sops-npmjs` and home
`ecosystem.sops.npmjs` modules own `npmjs_auth_token` and the `npmrc`
template, and base `sops` owns base settings only. The base `sops` modules
declare no npm artifacts.

## Synchronization

Update this ADR when changing the SOPS/OpenCode layering, option boundary,
template ownership, or Tangerine Dream abstraction. Keep `AGENTS.md` limited to
the generic rules and link here for these concrete lessons. Generic SOPS
changes belong in [ADR 0008](0008-sops-secrets-layer.md); nested-category
mechanics are in `docs/guides/nested-module-categories.md`.
