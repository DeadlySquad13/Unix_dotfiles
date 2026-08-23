# Sops
- Status: Accepted
- Scope: SOPS secret/template delivery to OpenCode MCP configuration

This ADR records the implementation-specific form of the generic layered
options guidance in `AGENTS.md`. Keep SOPS definitions, layer-specific glue,
and processed OpenCode configuration distinct.

## TDLR

Layered structure:

1. System
    1. Define base Sops system settings: ../../modules/nixos/ecosystem/sops/default.nix
    2. Define Opencode specific Sops settings: ../../modules/nixos/ecosystem/sops-opencode/default.nix
        - define secret,
        - define template.
    3. Tie into opencode config: ../../modules/nixos/ai-assistance/opencode/default.nix
        - symlink home-manager file to template.
2. Per-system overrides
    1. Override keyFile according to our docker volumes, set
       `ds-omega.ai-assistance.opencode` settings for system layer module:
    ../../systems/x86_64-docker/darkGreen-tangerineDream-green/apps/ecosystem/sops-opencode/default.nix
3. HomeManager
    1. Define sops settings: ../../modules/home/apps/ecosystem/sops/default.nix
    1. Define opencode settings:
       ../../modules/home/apps/ai-assistance/opencode/default.nix
       - takes into account that API keys can be defined by sops on any of the
         levels. The narrower level, the more priority it has.

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

### SOPS definitions and layer-specific glue

SOPS definitions and the modules that pass their generated paths to OpenCode
are separate responsibilities.

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

#### Home Manager layer

1. Base Home Manager SOPS behavior is defined in
   `modules/home/apps/ecosystem/sops/default.nix`.
2. `modules/home/apps/ecosystem/sops-opencode/default.nix` defines the home
   layer's secret and `logseq-mcp.env` template.
3. Per-home glue belongs in the home tree. For example,
   `homes/x86_64-linux/ds13@salt/apps/ecosystem/sops-opencode/default.nix`
   sets the namespace input from the Home Manager template path.

`sops-opencode` intentionally exists in both NixOS and Home Manager. Each
layer creates its own secret/template because its corresponding glue and
consumer live at that layer; neither definition is a duplicate substitute for
the other.

Tangerine Dream has a small intentional abstraction between the system module
and `sops-opencode`. It factors repeated system-specific SOPS behavior,
especially `username = systemBaseName`, so secret and template ownership
follows the system username. Treat this as deliberate abstraction, not
accidental duplication.

## Dependency flow

The flow is the same at each layer:

```text
sops-opencode definition at the owning layer
  -> config.sops.templates."logseq-mcp.env".path
  -> per-home or per-system namespace glue
  -> opencode mcp.nix consumes the namespace input
  -> programs.opencode.mcpContainers / generated Compose
```

The namespace option is user-facing input. `cfg` and
`programs.opencode.mcpContainers` are processed output. The latter must never
provide the former.

## Implementation rules

- Keep the SOPS definition enabled at the same layer as the glue that reads
  its template path.
- Keep per-home values in the home tree and per-system values in the system
  tree.
- Keep `cfg` in `mcp.nix` bound only to
  `config.programs.opencode.mcpContainers`.
- Preserve the repository namespace boundary instead of adding an external
  input to Home Manager's `programs.opencode` option space.

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

## Synchronization

Update this ADR when changing the SOPS/OpenCode layering, option boundary,
template ownership, or Tangerine Dream abstraction. Keep `AGENTS.md` limited to
the generic rules and link here for these concrete lessons.
