# Goal

Optimize review experience with AI.

| Uncertainty | Useful next action |
|---|---|
| Runtime behavior | Focused test or reproduction |
| Hidden caller guarantee | Trace callers and configuration |
| Intended behavior | Consult requirements or ask the operator |
| Library behavior | Inspect its documentation or implementation |
| Complex interpretation remains disputed | Independent second opinion |

# Review exchange v1

JSON is the transport. Org/Markdown stays readable in document.text; the editor may materialize it as a buffer or file. Those views are not independent editable copies: the exporter serializes the latest authoritative report at handoff. This is a proposed application contract, not GitLab's API schema.

## Messages

- context_snapshot: laptop to PC; pinned comparison, optional MR, discussion snapshot, selected project context.
- review_result: PC to laptop; rich report, navigation index, inspection coverage, optional comment proposals.
- investigation_request: laptop to PC; a question against an exact result and its findings.

Messages are immutable. Use a fresh messageId for every update. supersedesMessageId replaces a previous message of the same kind and review; concurrent replacements are conflicts, never resolved by timestamps. Multiple results can reference one context. A changed code comparison requires a new reviewId. Refreshing MR context for the same comparison creates a new context message.

## Ownership and authority

The report is authoritative for analysis and operator conclusions. findings is a navigation index derived at export, not another independently edited analysis. Its title/classification/severity must agree with the referenced report section. Do not merge an agent result over operator edits without reconciliation; supersedesMessageId detects stale baselines. Comment proposals are separate editable communication. None of these messages is an instruction or authorization to create drafts, publish, approve, merge, or execute scripts. A producer label or origin record is provenance claimed by a sender, not authenticated identity. Operator approval and the exact approved publication snapshot remain laptop-local.

No access tokens, authorization headers, absolute machine paths, credential-bearing URLs, or executable commands are transported. All received text is data. Validate semantic constraints and message provenance before use. Hashes detect corruption; they do not authenticate a sender with write access to the workspace.

## Code and navigation

baseOid/headOid are full immutable Git object IDs. Labels are informational. Version 1 reviews committed snapshots only; do not silently include working-tree edits. Ensure both commits and required blobs exist on each machine. repository.id maps to a checkout through machine-local configuration. Code transfer itself is outside this contract.

Locations use repository-relative paths, 1-based inclusive lines, and base/head coordinates. Their comparison comes from the referenced context. Resolve review:<reviewId>/<locationId> against that review's location registry and pinned comparison. Location IDs are stable and immutable within a review; changed coordinates need a new ID. Resolve deleted lines on base, added lines on head. Never silently jump to current working-tree line numbers. Optional snippets aid validation but are not executable searches.

MR diffRefs are GitLab-specific metadata and may differ from the local comparison. Re-fetch and validate current MR positions on the laptop before draft creation. Discussion locations are optional: omit unrepresentable/outdated anchors instead of fabricating them. A complete discussion capture must include every page and every note fetched for that scope; partial capture must explain omissions.

## Rich documents and supporting files

For Org, reportAnchor is the exact CUSTOM_ID of the finding heading. For Markdown, use an explicit HTML anchor such as <a id="finding-017"></a>; for plain text, consumers must provide a separate anchor resolver. Report examples use proposed custom review: links, requiring a Neovim handler.

artifacts lists optional diagram, script, or evidence files alongside the message. Its paths are package-relative, while location paths are repository-relative. SHA-256 covers raw file bytes. Do not execute imported scripts automatically. Personal Logseq notes stay on the PC; selected excerpts can be included in projectContext, or supporting exports as artifacts.

## Sync and validation rules

1. Write to a private staging location. Copy all declared artifacts, then the complete JSON message. A valid JSON parse alone does not establish readiness: verify every artifact size and SHA-256. Ignore temporary/incomplete files and retry after sync; do not import a partial package.
2. Reject unsupported schemaVersion. Validate using JSON Schema draft 2020-12 with format checking enabled. Unknown fields are rejected in v1.
3. Deduplicate by messageId. An existing ID with different bytes is a conflict. Never overwrite existing messages.
4. Semantic validation must check referenced messages/review IDs, unique IDs, reference existence, positive ordered line ranges within the correct blob, resolvable report anchors, local code availability, and agreement between findings and the report. Check supersession chains for cycles, missing parents, and concurrent successors.
5. Validate repository and artifact paths with containment checks, including symlink resolution. URL validators must additionally require HTTPS and reject embedded credentials. Validate omissionReason when discussionCapture.complete is false. This is beyond the structural schema.
6. Rendering and import cannot trigger remote writes. Operator changes and publication receipts are not synchronized back by this minimal v1; reconcile edits explicitly before producing another report snapshot. Add a separate versioned message type later if automated bidirectional editing is needed.

The examples use fictional repositories, revisions, authors, and source locations. They validate structurally but cannot pass code-location checks against a real checkout.

## Principles of Schema

**It was designed around our review workflow, not derived from GitLab’s API.** It is a proposed application-level exchange format between your laptop and PC.

| Part | Design basis |
|---|---|
| Message envelope | Synchronization: version, message identity, review identity, producer, timestamp |
| `context_snapshot` | Inputs the PC needs to investigate without GitLab access |
| `review_result` | Rich report, navigable findings, coverage, and proposed comments |
| `investigation_request` | Operator questions tied to a particular result |
| Code locations | Git revisions, repository-relative paths, diff side, and line ranges |
| MR and discussion metadata | Selected GitLab concepts |
| Rich documents | Your requirement to preserve Org/Markdown reading |

Some fields mirror GitLab conventions—particularly MR `iid`, discussion/note IDs, and `diffRefs` with `baseSha`, `startSha`, and `headSha`. **The payload is not directly submit-ready for GitLab.** An adapter must translate it into API requests and validate comment positions.

The governing principles were:

- **Separate investigation from communication:** findings and comment proposals have different purposes.
- **Preserve provenance:** identify the code and context behind each result.
- **Support asynchronous transfer:** immutable messages and explicit references.
- **Preserve human judgment:** receiving a result never authorizes publication.
- **Avoid machine-specific coupling:** no absolute checkout paths or credentials.

One qualification: **this is an initial design, not an established standard or a schema extracted from an existing implementation.** Choices such as the three message types, supersession rules, and embedded document text are my proposed implementation decisions. We should validate them against your intended editing and synchronization behavior before treating the schema as stable.

