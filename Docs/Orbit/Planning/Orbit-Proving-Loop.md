# Orbit Proving Loop Implementation Plan

Status: Draft
Owner: Samwise
Meeting: `2026-03-09-meeting-002`
Workspace: Orbit
Revision: 3
Last Updated: 2026-03-10

## Purpose

Translate the approved proving-loop and macOS command-center artifacts into a
first implementation-facing plan.

This document should answer:

- what we build first
- what can wait
- what sequence keeps the loop small but real

## Inputs

This plan builds on:

- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
- the proving-loop direction approved in Meeting 001

These are treated as approved planning inputs for this implementation pass.

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

## Deferred From This Plan

Not required for the first implementation loop:

- summary generation
- memory candidate review
- memory reuse
- iPhone or iPad clients
- deep squad management
- broad specialist roster generation
- cross-workspace memory promotion
- automated gardening
- analytics-heavy trace inspection
- elaborate meeting visualization

## Suggested First Build Boundary

If we need to be even stricter, the first serious implementation target should
stop at:

- Phase 1
- Phase 2
- enough of Phase 3 to make multi-participant interaction legible

This is the current proving checkpoint for fresh-main reruns.
Later summary and memory phases remain explicitly deferred until this checkpoint
is proven again.

At that checkpoint, the system should be able to:

- open the Orbit workspace
- show the founding-group roster
- persist a conversation thread
- allow AJ to address one or more participants
- attribute responses to the correct persona

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
