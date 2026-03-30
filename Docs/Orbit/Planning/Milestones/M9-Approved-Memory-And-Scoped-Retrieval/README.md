# M9 Approved Memory, Lineage, And Scoped Retrieval

Status: Planned
Primary Owner: `orbit-memory-gardener`
Supporting Personas: `architectural-editor`, `studio-coverage-architect`, `venture-product-steward`
Last Updated: 2026-03-30

## Purpose

Let approved memory influence future work without becoming hidden magic.

## Preconditions

- `M8` review workflow is trusted
- the approved-memory scope model is frozen before implementation begins
- activation trace inspection is already a normal part of Orbit review

## Scope Freeze

In scope:

- approved memory entries
- memory links
- persona-global memory profiles
- scoped retrieval rules
- activation-memory-source visibility
- lineage inspection

Out of scope:

- automatic cross-workspace promotion
- large-scale contradiction management
- implicit retrieval that cannot be inspected

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `M8` evidence package

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Packet-01-Freeze-Approved-Memory-Scope-Rules.md`
  bounded planning packet for `M9-P1`

## Current Milestone Position

- `Docs/Current-State.md` identifies `M9-P1` as the active current work item
- accepted `M8` closeout is the frozen handoff boundary into `M9`
- `M9-P1` is accepted as the bounded packet that freezes approved-memory scope
  meaning only
- later `M9` packets remain intentionally unfrozen and must not smuggle in
  retrieval, activation, lineage, or implementation work under the scope-freeze
  label

## Execution Packets

### Packet 1. Freeze Approved-Memory Scope Rules

Outcome:

- each memory scope has one stable meaning

Work:

- define workspace scope
- define workspace persona scope
- define persona-global scope
- define optional organization scope and its default off posture

Done when:

- scope contamination risks can be tested explicitly

Status:

- accepted

### Packet 2. Implement Approved Memory Records

Outcome:

- reviewed memory becomes a durable runtime artifact

Work:

- add approved-memory records
- add memory links and profile records
- preserve lineage from candidate to approved memory

Done when:

- a reviewed candidate can become durable approved memory with visible lineage

### Packet 3. Implement Retrieval Eligibility Rules

Outcome:

- future activations can use memory only through explicit, scoped rules

Work:

- define eligible versus ineligible retrieval paths
- encode safe defaults
- block cross-scope retrieval unless explicitly allowed

Done when:

- retrieval behavior is predictable and reviewable

### Packet 4. Implement Trace And Lineage Inspection

Outcome:

- operators can see which memory influenced a response and why

Work:

- surface activation-memory-source linkage
- surface lineage and traversal paths
- keep the first UI simple but sufficient for review

Done when:

- one response can show its memory influence cleanly

### Packet 5. Run Regression And Governance Review

Outcome:

- memory reuse is trusted because it can be tested and inspected

Work:

- run scope regression suite
- run activation trace review
- run product review on explainability burden versus value

Done when:

- approved memory reuse can be treated as a real Orbit feature rather than an
  opaque trick

## Subagent Use Pattern

Safe subagents:

- retrieval-boundary review
- lineage review
- activation-trace review
- memory-scope regression review

Avoid:

- parallel changes to retrieval rules and UI wording without one owner

## Evidence Package

- memory scope note
- `Packet-01-Freeze-Approved-Memory-Scope-Rules.md`
- approved memory example with lineage
- retrieval eligibility matrix
- activation trace example with memory influence
- regression and governance review artifacts

## Stop Points

- stop if approved memory starts mutating authored persona definitions
- stop if scope meaning requires retrieval, activation, lineage, or promotion
  semantics to be understandable
- stop if retrieval paths cannot be explained in the UI or evidence packet
- stop if scope leakage appears in tests

## Exit And Handoff

Exit when approved memory can influence a later response and the operator can see
what happened and why.

Handoff forward to:

- `M10` for gardening, contradiction handling, and broader promotion rules
