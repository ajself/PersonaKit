# M10 Memory Gardening, Contradiction Handling, And Cross-Workspace Promotion

Status: Planned
Primary Owner: `orbit-memory-gardener`
Supporting Personas: `samwise`, `venture-product-steward`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Make memory maintainable over time instead of merely accumulated.

## Preconditions

- `M9` approved-memory retrieval is already trusted
- there is enough durable memory to justify gardening workflows
- AJ has approved the baseline cross-workspace promotion posture

## Scope Freeze

In scope:

- duplicate clustering
- contradiction and supersession review
- scheduled gardening cadence
- richer cross-workspace promotion rules
- memory audits and quality metrics

Out of scope:

- fully autonomous global memory promotion
- opaque scoring systems that drive promotion without review

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
- `M9` evidence package

## Execution Packets

### Packet 1. Freeze Gardening Workflow

Outcome:

- gardening becomes a repeatable stewardship loop instead of occasional cleanup

Work:

- define cadence
- define who reviews what
- define how gardening actions are recorded

Done when:

- scheduled gardening can happen without inventing new process every time

### Packet 2. Implement Duplicate And Contradiction Review

Outcome:

- the system can surface memory conflicts intentionally

Work:

- detect likely duplicates
- detect contradiction and supersession cases
- present review actions that preserve lineage

Done when:

- conflict review can happen without directly mutating memory in place

### Packet 3. Implement Promotion Policy Beyond One Workspace

Outcome:

- cross-workspace learning becomes explicit and earned

Work:

- define promotion prerequisites
- define evidence needed for promotion
- define explicit AJ approval steps for broader scope promotion

Done when:

- cross-workspace promotion no longer depends on informal judgment alone

### Packet 4. Implement Audit And Metric Surfaces

Outcome:

- memory quality can be governed over time

Work:

- define memory health signals
- define audit views
- keep metrics explanatory, not vanity analytics

Done when:

- stewards can see quality trends and unresolved problems clearly

## Subagent Use Pattern

Safe subagents:

- duplicate-analysis review
- contradiction review
- promotion-policy review
- audit and metric review

Avoid:

- delegating final promotion authority to an unreviewed background loop

## Evidence Package

- gardening workflow note
- duplicate and contradiction examples
- cross-workspace promotion policy note
- audit and metric examples

## Stop Points

- stop if cross-workspace promotion loses explicit AJ approval
- stop if contradiction handling rewrites history instead of preserving lineage
- stop if metrics replace review judgment instead of supporting it

## Exit And Handoff

Exit when memory quality can be reviewed intentionally over time and broader
promotion remains governed.

Handoff forward to:

- later multi-workspace and institutional-memory planning
