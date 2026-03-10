# Orbit Product Acceptance Checklist

Status: Draft
Owner: Venture Product Steward + Studio Interaction Quality Lead
Last Updated: 2026-03-10

## Purpose

Define the minimum first-checkpoint product bar before an Orbit build can be
described as `review-ready` or `MVP candidate`.

This checklist is for the first checkpoint only:

1. Phase 1
2. Phase 2
3. minimal Phase 3

## First-Open State

All of these should be true on first open:

1. roster starts in a neutral state
   - no participant is pre-highlighted without explicit user intent
2. primary action language is stable
   - the main action should not switch meaning between address modes
3. panel composition is top-aligned and visually stable
4. the main Orbit panel does not rely on inline help disclosure to explain the
   interaction model
5. workspace context is visible and legible on first scan

## Persistent Collaborator Presence

All of these should be true:

1. AJ, Samwise, and ProdDoc are visibly present as durable participants
2. the roster reads like persistent collaborators rather than static labels
3. participant presence supports the command-center framing instead of generic
   chat framing

## Conversation And Persistence

All of these should be true:

1. a conversation thread can be started or resumed
2. the thread persists across app restart
3. speaker attribution remains visible and understandable
4. the discussion surface feels like a workspace thread, not just a message
   scratchpad

## Activation Trace And Meeting Behavior

All of these should be true:

1. lightweight multi-participant behavior is understandable enough to review
2. activation trace is visible, legible, and not hidden behind unrelated UI
3. activation trace is lightweight, but still reads as part of Orbit's product
   identity

## Orbit-Specific Product Bar

All of these should be true:

1. the surface feels structurally different from generic chat
2. the screen embodies its own interaction model instead of explaining it
3. the room metaphor is supported by structure and state, not by copy alone

## Failure Conditions

Do not describe the build as `review-ready` or `MVP candidate` if any of these
remain true:

1. a participant is highlighted by default without explicit intent
2. the primary action changes meaning by changing its label in place
3. the layout drifts vertically or loses top anchoring under normal use
4. inline help is still required for the panel to make sense on first open
5. the product still reads more like generic chat than Orbit command center

## Result Artifact Rule

This checklist defines the product bar.
Each attempt must record its checklist result in a separate attempt-specific
artifact rather than rewriting an older attempt's acceptance result.

For the next run, record the result in:

- `Docs/Orbit/Execution/2026-03-10-orbit-1-product-acceptance.md`

Do not edit the `orbit-foundation` acceptance evidence except for explicit
historical correction.

## Review Record

Record these with the checklist result:

1. result artifact path
2. reviewer names
3. decision:
   - `pass`
   - `pass with notes`
   - `fail`
4. short notes on the strongest product issue still present
