# Orbit Proving Loop Implementation Plan

Status: Draft
Owner: Samwise
Meeting: `2026-03-09-meeting-002`
Workspace: Orbit
Revision: 3
Last Updated: 2026-03-18

## Purpose

Translate the approved proving-loop and macOS command-center artifacts into a
first implementation-facing plan.

This document should answer:

- what we build first
- what can wait
- what sequence keeps the loop small but real

## Inputs

This plan builds on:

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
- the proving-loop direction approved in Meeting 001

These are treated as approved planning inputs for this implementation pass.

## Current Role In The Planning Stack

This document is the phase model for the first Orbit proving loop.

It remains useful because it explains the shape and sequencing of the first
product proof, but it is no longer the top-level planning authority.

Use it this way:

- roadmap decides the milestone order
- execution plan decides the active first-checkpoint contract
- this file explains the phase shape behind that contract

For startup order, review gates, and completion language, defer to
`Docs/Orbit/Planning/Orbit-Execution-Plan.md`.

## Implementation Goal

Build the smallest real Orbit loop inside a macOS command-center surface where:

1. the Orbit workspace is visible
2. AJ can interact with Samwise and ProdDoc as durable participants
3. conversation state persists
4. lightweight multi-participant discussion is possible
5. activation context is visible enough that responses feel attributable rather
   than opaque

## Implementation Strategy

The proving loop should be built from center outward.

That means:

1. establish the minimum durable runtime state
2. expose it through the macOS command-center surface
3. treat summary and memory work as later-phase follow-on only after the base
   checkpoint is coherent and re-approved

We should not begin with broad platform abstractions if they do not directly
serve the first loop.

## Proposed Phases

### Phase 1: Workspace and Roster Foundation

Goal:
Make the app visibly Orbit before it behaves like Orbit.

Must include:

- Orbit workspace context visible in macOS UI
- founding-group roster visible in workspace
- durable local model for workspace participants

Success signal:

- AJ can open the app and immediately see Orbit, Samwise, and ProdDoc in one
  coherent workspace context

### Phase 2: Durable Conversation Loop

Goal:
Make discussion persist and feel attributable.

Must include:

- durable conversation thread
- visible speaker attribution
- ability for AJ to start or continue a discussion
- persistence across restart

Success signal:

- AJ can hold a short discussion, close the app, return, and still see the same
  thread state

### Phase 3: Lightweight Meeting and Activation Trace

Goal:
Make multi-participant interaction intentional and explainable.

Must include:

- ability to address one participant or trigger a lightweight multi-participant
  exchange
- persisted activation context for each persona response, including:
  - responding persona
  - directive used
  - trigger message or meeting invocation source
- basic activation trace visibility showing:
  - responding participant
  - directive used
  - whether memory influenced the response

Success signal:

- a short multi-participant exchange can happen without feeling like hidden
  model routing

### Phase 4: Summary and Memory Review

This phase is not part of the current first-checkpoint rerun contract.

Goal:
Turn discussion into governed learning.

Must include:

- summary artifact generated from a discussion or meeting
- at least one proposed memory candidate
- review action for approve or reject

Success signal:

- AJ can review a real candidate memory inside the app

### Phase 5: Memory Reuse

This phase is not part of the current first-checkpoint rerun contract.

Goal:
Close the loop and prove Orbit learns in a visible way.

Must include:

- approved memory becomes available to later responses
- later response exposes that memory influence in a lightweight explainable form

Success signal:

- AJ can observe an approved memory affecting a later response

## Roadmap Mapping

The broader roadmap now makes the later follow-on clearer:

- Phase 1 + Phase 2 + minimal Phase 3 map to `M2`
- workspace persona and activation discipline that make Phase 3 trustworthy map
  to `M1`
- richer team, squad, and meeting coordination move into `M4` and `M5`
- summary, journaling, and memory candidate review move into `M8`
- approved memory reuse moves into `M9`
- canonical Orbit Server and multi-client work move into `M3`, `M11`, `M12`,
  and `M13`

## Deferred Beyond The Current Checkpoint

This file keeps the later phases visible, but they are not part of the active
first-checkpoint rerun contract.

Still deferred:

- Phase 4 summary and memory review work
- Phase 5 memory reuse
- iPhone or iPad clients
- deep squad management
- broad specialist roster generation
- cross-workspace memory promotion
- automated gardening
- analytics-heavy trace inspection
- elaborate meeting visualization

When one of those areas becomes active, return to the roadmap instead of
expanding this proving-loop note into a broader platform plan.

## Current Checkpoint Freeze

The exact active rerun contract lives in
`Docs/Orbit/Planning/Orbit-Execution-Plan.md`.

This file only freezes the phase interpretation:

- build through Phase 1 and Phase 2
- include only enough of Phase 3 to make multi-participant interaction and
  activation trace legible
- stop before Phase 4 and Phase 5

Use the execution plan for:

- milestone definition of done
- startup artifact order
- rerun review gates
- comparison-grade evidence expectations

## Open Implementation Questions

- Should ProdDoc be modeled as a first-class local participant immediately, or
  introduced through a lighter representation first?
- What is the smallest durable storage mechanism acceptable for the first loop?
- What is the cleanest later-phase seam for summary and memory work once the
  first checkpoint is re-proven?

## Review Questions

For AJ and ProdDoc, the most useful review feedback is:

1. is the phase order correct
2. is anything missing from the implementation sequence
3. is anything here still too broad for the first build
4. where should the first engineering checkpoint happen

## Revision Notes

- 2026-03-09: Initial Samwise draft created from Meeting 002.
- 2026-03-09: Integrated ProdDoc review by clarifying Phase 3 activation
  recording and making the first engineering checkpoint more explicit.
- 2026-03-10: Re-scoped the active proving loop so fresh-main reruns stop at
  Phase 1, Phase 2, and minimal Phase 3; summary and memory work remain later
  phases only.
- 2026-03-18: Repositioned this file as the phase-shape reference beneath the
  roadmap and execution plan, and mapped the deferred phases to later roadmap
  milestones.
- 2026-03-18: Reduced overlap with the execution plan by keeping this file on
  phase shape and deferring active rerun contract details to the execution plan.
