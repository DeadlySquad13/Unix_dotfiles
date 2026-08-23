# Agent guide

Use this guide for changes anywhere in the repository. Keep changes small,
understandable, and consistent with the existing module and documentation
structure.

## Architecture boundaries

- Find the owning module, option, or generator before editing a consumer.
- Preserve boundaries between reusable modules, repository-level user-facing
  inputs, processed program configuration, and host/user-specific glue.
- Prefer extending an existing abstraction over duplicating behavior. Add an
  abstraction only when it removes real repeated behavior and keeps ownership
  clear.

## Generated files

- Treat generated files as outputs. Change their source or generator, then
  regenerate them.
- Do not hand-edit generated output unless the repository explicitly requires
  it.

## Layered options

Keep inputs and processed configuration separate. Reusable modules should define
behavior and options. Repository namespace options should expose values that a
host or user supplies. Program modules should consume those inputs to produce
processed program configuration. Per-host or per-user glue should connect the
appropriate local values to the namespace options at the layer that owns them.

Do not make processed configuration provide the input used to construct it, and
do not hide host/user-specific wiring in a reusable module. See
`docs/adr/sops-opencode.md` for the concrete SOPS/OpenCode example and its
implementation lessons.

See .[Configuration Layers diagram](./docs/_diagrams/ConfigurationLayers_diagram.puml).

## Secrets and safety

- Do not commit plaintext secrets, private keys, tokens, or rendered secret
  files. Use the repository's established secret mechanism and references.
- Avoid logging secret values and avoid broadening permissions or exposure.
- Check ownership, evaluation context, and runtime boundaries before changing
  secret-backed paths or services.

## Validation

- Inspect nearby tests, checks, Make targets, and evaluation commands before
  choosing validation.
- Run the narrowest relevant formatter, linter, evaluator, test, or build
  after editing. Expand validation when a shared module or interface changes.
- Treat failures, timeouts, and interrupted commands as incomplete; fix or
  narrow the check and retry.
- Review the final diff for unintended source, generated, secret, or unrelated
  changes. Do not commit unless explicitly asked.

## Documentation synchronization

- Update the governing ADR or guide when an implementation lesson, boundary,
  workflow, or invariant changes.
- Keep agent guidance concise and generic; put domain-specific rationale and
  examples in the relevant ADR or guide.
- Use standalone repository-relative paths such as
  `docs/adr/sops-opencode.md`, and keep references valid after edits.
