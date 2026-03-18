# M5 Meeting Promotion And Continuity

Status: Planned
Primary Owner: `orbit-meeting-coordinator`
Supporting Personas: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Let a message-thread discussion move into meeting mode or a promoted meeting post
without losing continuity.

## Preconditions

- `M4` inline group collaboration is trusted
- canonical runtime and linking semantics from `M3` are stable
- coordinator behavior is approved enough to manage meeting transitions

## Scope Freeze

In scope:

- lightweight meeting mode in the originating discussion
- promoted meeting-post creation with continuity links
- meeting-state and meeting-member records
- visible completion state
- meeting outputs such as summary shell, decision or no-decision state, open
  questions, and follow-up references

Out of scope:

- deep facilitator personalities or advanced deliberation systems
- workstream handoff automation beyond what continuity needs
- memory candidate generation from meeting output

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `M4` target-expansion and group-collaboration evidence

## Execution Packets

### Packet 1. Freeze Meeting Trigger Rules

Outcome:

- the system knows when a thread stays inline and when it should enter meeting
  mode

Work:

- define lightweight meeting trigger conditions
- define explicit promotion conditions
- define how the operator can inspect or override the transition

Done when:

- meeting transitions no longer depend on hidden heuristics

### Packet 2. Implement Meeting-State Runtime Records

Outcome:

- meeting behavior has durable runtime state instead of ad hoc flags

Work:

- add meeting-state records
- add meeting-member records
- preserve links back to the originating post and thread

Done when:

- meeting lifecycle can be reconstructed from runtime records alone

### Packet 3. Implement Promotion And Continuity Links

Outcome:

- promoted meetings preserve conversational lineage

Work:

- link message post to meeting post
- keep origin references visible in both places
- preserve attribution and participant context

Done when:

- a reader can move between the origin thread and promoted meeting without losing
  context

### Packet 4. Implement Meeting Outputs

Outcome:

- meeting results are durable and inspectable

Work:

- add summary shell
- add decision or no-decision state
- add open questions and follow-up references
- keep output shape small enough for the first meeting slice

Done when:

- a meeting can close with explicit outcomes rather than implicit thread drift

### Packet 5. Prove Completion And UX Legibility

Outcome:

- meetings feel intentional and reviewable

Work:

- define visible completion semantics
- run interaction review on continuity surfaces
- run validation against history preservation and participant attribution

Done when:

- the operator can tell what happened, who participated, and what remains open

## Subagent Use Pattern

Safe subagents:

- meeting state-machine review
- continuity-link review
- summary-quality review
- interaction review for meeting ergonomics

Avoid:

- parallel expansion into workstream behavior before meeting continuity is trusted

## Evidence Package

- meeting trigger note
- meeting-state examples
- continuity-link examples
- meeting output examples
- interaction and validation review artifacts

## Stop Points

- stop if promotion breaks post lineage
- stop if meeting outputs are being mistaken for memory artifacts
- stop if completion state is not visible and inspectable

## Exit And Handoff

Exit when a discussion can enter meeting mode or promote cleanly and preserve
continuity end to end.

Handoff forward to:

- `M6` for richer structured outputs
- `M7` for workstream handoff from meeting conclusions
