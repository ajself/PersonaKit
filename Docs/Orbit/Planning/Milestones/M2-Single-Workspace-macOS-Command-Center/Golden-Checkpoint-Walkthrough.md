# Golden Checkpoint Walkthrough

Status: Draft
Milestone: `M2`
Owners: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Provide one deterministic walkthrough of a convincing first-checkpoint Orbit run.

This is not just a UI demo script.
It is the smallest believable product proof that should survive product,
interaction, and validation review.

## Preconditions

- `M1` is accepted as the identity and activation foundation
- the founding roster naming is frozen for the checkpoint
- the local runtime and persistence boundary are already aligned with the
  runtime-model note

## Scene 1. First Open

Expected state:

- AJ opens the app and lands in the Orbit workspace without hidden setup
- the workspace name and short purpose are visible immediately
- the founding roster is visible and reads like persistent collaborators
- the active thread surface is present and legible

Why this matters:

- if the first scan fails, the room never establishes itself as Orbit

Disqualifying deviations:

- the workspace identity is hard to spot
- the roster looks like disconnected labels
- the room only makes sense after inline help

## Scene 2. Direct Address

Example turn:

> Samwise, what is Orbit trying to prove in this workspace?

Expected state:

- the message appears in the active thread
- Samwise's response is visibly attributed
- the response feels like a room participant speaking, not a generic system
  answer

Why this matters:

- the first collaborator response is the moment the room either feels real or
  collapses into chat

Disqualifying deviations:

- the answer appears with weak or unclear speaker identity
- the response feels detached from the room model

## Scene 3. Trace Inspection

Expected state:

- AJ can inspect lightweight trace information for the response
- the trace shows enough to answer why the response happened
- the trace does not dominate the screen or require leaving the command center

At minimum the trace should reveal:

- responding participant
- directive used
- whether memory influenced the response

Disqualifying deviations:

- trace is hidden, negligible, or debug-like
- trace exists but does not help explain the response

## Scene 4. Restart Durability

Expected state:

- AJ closes and reopens the app
- the same Orbit workspace returns
- the same thread and prior response remain visible
- attribution remains intact after reload

Why this matters:

- durability is one of the clearest differences between a proving room and a
  disposable chat shell

Disqualifying deviations:

- the thread is lost or incomplete after restart
- attribution is degraded after reload

## Scene 5. Lightweight Multi-Participant Exchange

Expected state:

- AJ can trigger a minimal multi-participant interaction path
- the resulting behavior is understandable enough to review
- the exchange still feels like one room, not hidden routing across invisible
  agents

Why this matters:

- this is the first point where Orbit must prove collaboration rather than solo
  persona response

Disqualifying deviations:

- participants appear to respond for opaque reasons
- the exchange feels accidental, noisy, or fake

## Walkthrough Success Rule

This walkthrough passes only if a reviewer can say all of the following:

- the room is clearly Orbit
- collaborators feel durable
- discussion persists
- responses are attributable
- the trace explains enough to trust the interaction
- multi-participant behavior feels intentional

If one of those claims is weak, the walkthrough is not a convincing hero proof.
