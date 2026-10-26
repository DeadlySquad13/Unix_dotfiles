# Intentionally empty. npm SOPS ownership moved to the `sops-npmjs` domain
# module at `./sops-npmjs/default.nix`; the base `sops` module owns base
# settings only. This file is not imported by the host. See
# docs/adr/0008-sops-secrets-layer.md.
{...}: {}
