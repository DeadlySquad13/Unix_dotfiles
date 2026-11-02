## Workflow

### Prepare the review on the laptop

An explicit “prepare review” action captures:

- MR description and relevant discussions, including IDs and URLs.
- Repository identity and MR identity.
- Exact base and head commit IDs.
- Context retrieval time.
- Changed-file inventory.
- Relevant requirements you choose to include.
Save these as a versioned input snapshot. Refreshing GitLab context creates another snapshot rather than overwriting the evidence used by an ongoing review.

Keep authentication configuration, tokens, and credential-bearing remote URLs outside this workspace.

### Make sure the PC has the exact reviewed code

Synced project files alone do not guarantee that both machines have the same Git objects or working state.

Before investigation, the PC should verify that it can read the manifest’s base and head revisions. If those revisions are unavailable, transfer the necessary Git history or an explicit source snapshot from the laptop.

The review should say, for example:
Reviewing comparison X, using GitLab context snapshot Y.

This keeps a background sync or branch update from silently changing the subject of the review.

Use repository-relative paths in findings. Each machine supplies its own mapping:
repository identity → local checkout

That lets the same report link open code on either machine despite different directories.

### Investigate and maintain the report on the PC

The agents use the pinned code and exported GitLab context. They need no GitLab credentials.

Your Org/Markdown report remains the main reading surface, with validated links to reviewed code, evidence, questions, and dispositions. Diagrams and reproduction scripts travel alongside it.

Give the files clear ownership:
Material	Writer
GitLab context snapshots	Laptop exporter
AI proposals and investigation evidence	PC agents
Operator conclusions and edited comment wording	You
Remote draft/publication mappings	Laptop publisher

In particular, agents should add proposals without rewriting your conclusions. Avoid having both machines edit the same report simultaneously; explicit handoff is enough for an initial implementation.

### Return findings to the laptop for inspection

After sync completes, the laptop opens the report beside the pinned Diffview comparison.

The first implementation only needs two explicit actions:

- Prepare review package on the laptop.
- Open review package on either machine.
Later, a completion marker can indicate that all files belonging to an update have arrived. This prevents opening a newly synced report before its location index or supporting evidence is present.

When you request additional investigation, record the question against the finding’s stable ID. The PC updates that finding’s evidence instead of producing a disconnected second report.

### Publish from a laptop-owned snapshot

Select findings, prepare colleague-facing wording, and load the selected batch into laptop editor buffers.

Before creating GitLab drafts, refresh the MR and check:

- Has its head revision changed?
- Does the finding still apply?
- Is the comment location still valid?
- Has someone already raised or resolved the issue?
A newer MR revision should trigger reassessment of affected findings, not automatic relocation of comments.

Publish the exact text you inspected. Once a batch is loaded for approval, subsequent PC updates must not silently alter it.

### Keep Logseq on the PC as the curated knowledge destination

The portable report should remain readable without Logseq running. It can contain ordinary references to project contracts and notes, but essential evidence should be available in the review package itself.

After your decision, promote selected lessons into Logseq on the PC:

- Link back to the review and finding ID.
- Preserve the reviewed revision and evidence.
- Include your conclusion and its scope.
- Export relevant approved lessons into future review packages when useful.
You do not need to sync your whole personal graph to the laptop. If a particular note is needed there, include a selected excerpt or exported copy with its provenance.

The resulting loop is: laptop prepares context → PC investigates → laptop inspects and communicates → PC preserves lessons. Existing sync carries the artifacts; explicit actions control transitions. A live MCP connection can remain an optional later convenience rather than a prerequisite.
