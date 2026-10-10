# Logseq reference discipline (always on)

Applies to every agent that reads or writes the Logseq graph. The full
conventions live in the `logseq-authoring` skill; this is the invariant.

- `((uuid))` is an **embed**, not a citation. Logseq renders the referenced
  block's content inline, and nested refs expand too. If you want to put `((uuid))`
  inline in a report or prose body, make sure the block it references is short
  (one small-medium sentense).
- Cite items by their plain label (`X1`, `F7`, `AC3`) and link the owning page
  once with `[[page]]`. Do not inline a UUID just to name an item.
- Prefer semantic relationships defined via properties like `:related:`,
  `:source-block:`, `:derived-from:` for independent blocks. If the block is
  a part of a bigger prose, put references inline.
- Never hand-copy or guess a UUID; take it from the blocks you read or from a
  batch resolver.
- Before finishing, verify every `((uuid))` you wrote resolves; drop or fix
  dangling refs. Logseq silently downgrades a dangling ref to plain text and
  never repairs it.
- Cite the copy you can actually read: never pair a `[[page]]` link with block
  UUIDs from a different copy of the same artifact.
