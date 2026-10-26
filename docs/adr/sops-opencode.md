# Sops (superseded)

- Status: Superseded by [ADR 0008](0008-sops-secrets-layer.md) and
  [ADR 0009](0009-sops-opencode.md)
- Date: 2026-10-26
- Superseded-by: [ADR 0008](0008-sops-secrets-layer.md) (generic SOPS layer),
  [ADR 0009](0009-sops-opencode.md) (OpenCode-specific application)

This combined ADR was decomposed on 2026-10-26. The generic SOPS layer
decisions now live in ADR 0008; the OpenCode-specific decisions now live in
ADR 0009. All decisions, rationale, examples, code blocks, references, and
caveats from this document were carried into one of those two ADRs.

| Former section | New home |
| --- | --- |
| Title / scope / introduction | ADR 0008 (generic contract) and ADR 0009 (OpenCode application) |
| `## TDLR` | ADR 0009 (OpenCode instance); generic form in ADR 0008 |
| `## Context` | ADR 0008 (generic ownership split); ADR 0009 (OpenCode instance) |
| `### OpenCode boundary` | ADR 0009 |
| `### home.file auth must not shadow the runtime-home-bridge symlink` | ADR 0009 |
| `### SOPS definitions and layer-specific glue` | ADR 0008 (ownership model); ADR 0009 (OpenCode layers) |
| `#### NixOS system layer` | ADR 0009 (OpenCode); ADR 0008 (generic npm split) |
| `#### Home Manager layer` | ADR 0009 (OpenCode); ADR 0008 (generic npm split) |
| `## Dependency flow` | ADR 0009 (OpenCode); generic flow in ADR 0008 |
| `## Implementation rules` | ADR 0008 (generic) and ADR 0009 (OpenCode) |
| `## Troubleshooting` | ADR 0008 (generic); ADR 0009 (OpenCode specifics) |
| `## Synchronization` | ADR 0008 and ADR 0009 |
| npm credential ownership (`npmjs_auth_token`, `npmrc`) | ADR 0008 (`sops-npmjs` domain module) |

The later `sops-npmjs` domain split (still 2026-10-26) moved npm credentials
out of base `sops` and `sops-opencode` into
`modules/{nixos,home}/.../sops-npmjs`. That domain split is documented in
ADR 0008; it is not an OpenCode concern and is intentionally absent from
ADR 0009.

Use ADR 0008 for any SOPS consumer and for the `sops-npmjs` domain; use ADR
0009 for `sops-opencode`.
