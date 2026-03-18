# M8 Journaling And Memory Candidate Review

Status: Planned
Primary Owner: `orbit-memory-gardener` or blocked until that persona exists
Supporting Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Turn important activity into reviewed learning proposals instead of automatic
behavioral drift.

## Preconditions

- `orbit-memory-gardener` exists as an approved persona
- `M7` provides real discussion, meeting, or workstream activity worth
  compressing
- activation trace and structured object lineage are already inspectable

## Scope Freeze

In scope:

- journal entries
- journal-source records
- memory candidates
- memory-review workflow
- manual approve, reject, and revise actions

Out of scope:

- approved memory influencing activations
- cross-workspace promotion
- automated gardening and contradiction resolution

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `M6` structured object evidence
- `M7` workstream evidence

## Execution Packets

### Packet 1. Freeze Journal Source Rules

Outcome:

- the system knows which artifacts may seed journaling and under what policy

Work:

- define normal journal sources
- define exceptions for raw runtime artifacts
- define cadence and trigger policy for the first slice

Done when:

- journal creation no longer feels arbitrary

### Packet 2. Implement Journal Records

Outcome:

- reflective compression becomes a first-class artifact

Work:

- add journal-entry records
- add journal-source records
- preserve lineage back to posts, meetings, decisions, and workstreams

Done when:

- one real collaboration sequence can produce a durable journal artifact

### Packet 3. Implement Candidate Staging

Outcome:

- memory proposals exist as a governed layer between lived activity and trusted
  memory

Work:

- add memory-candidate records
- capture proposed summary and scope
- capture why the memory matters and what future work it should influence

Done when:

- one journal can seed one reviewable candidate cleanly

### Packet 4. Implement Review Workflow

Outcome:

- the operator can govern candidate memory explicitly

Work:

- add approve, reject, and revise actions
- add candidate review surfaces
- keep review logic visible and attributable

Done when:

- the operator can review a candidate without leaving hidden state behind

### Packet 5. Run Governance Review

Outcome:

- the feature proves responsible memory staging instead of accidental drift

Work:

- validate that raw history does not become trusted memory by default
- validate review traceability
- run UX review on candidate clarity and burden

Done when:

- the governance reviewers agree the staging layer is real and usable

## Subagent Use Pattern

Safe subagents:

- journal generation review
- candidate staging review
- review-surface UX review
- governance validation review

Avoid:

- letting candidate generation become auto-approval through convenience shortcuts

## Evidence Package

- journal-source policy note
- real journal example
- real memory candidate example
- review workflow example
- governance and UX review artifacts

## Stop Points

- stop if `orbit-memory-gardener` is not approved
- stop if candidates begin affecting activation before `M9`
- stop if review burden becomes too high without staged prioritization

## Exit And Handoff

Exit when important activity can produce journals and candidates that the
operator can review explicitly.

Handoff forward to:

- `M9` for approved memory and retrieval
