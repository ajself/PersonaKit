# Operator Trace Walkthrough

Status: Accepted
Milestone: `M1`
Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Show what AJ should be able to inspect in the first-checkpoint Orbit UI when one
activation succeeds and when one activation is blocked.

## Successful Response Walkthrough

Scenario:

- AJ sends a direct message to Samwise in the active Orbit thread
- Orbit resolves Samwise to one workspace persona instance and one PersonaKit
  persona template
- Orbit persists an activation record and a contract snapshot before presenting
  the collaborator response

Expected visible trace under the response message:

1. one line for workspace persona identity and persona-template identity
2. one line for directive, response mode, and memory posture
3. one line for contract posture covering kits, authorized skills, stop points,
   review gates, and memory scopes

Minimum review readout:

- AJ can tell which runtime identity responded
- AJ can tell which authored identity governed the response
- AJ can tell whether memory influenced the response
- AJ can tell that empty contract sets were explicit, not omitted

## Blocked Response Walkthrough

Scenario:

- AJ addresses an unknown collaborator or one with missing identity/contract
  data
- the same blocked-state pattern should also hold when the required skill posture
  is not authorized
- Orbit blocks before publishing a collaborator response
- if contract grounding cannot reach a readable PersonaKit scope, Orbit should
  show an explicit contract-unavailable error outside the thread and leave the
  durable thread untouched
- if durable write itself fails, Orbit should leave the prior durable thread
  untouched and show an explicit persistence-blocked error outside the thread

Expected visible trace in the thread:

1. the user message remains visible
2. a blocked system event appears instead of a collaborator response
3. the blocked system event exposes a short failure trace with:
   - failure reason
   - target identity or addressed target
   - workspace persona and persona-template ids when known
   - required-versus-authorized skill posture when that is the reason for the
     block

Minimum review readout:

- AJ can tell the system blocked intentionally
- AJ can tell why the block happened
- AJ can tell the block did not silently degrade into a fake collaborator reply
- AJ can tell when the failure happened before any new durable thread state was
  committed
- AJ can distinguish contract-grounding failure from pure write failure

## Review Standard

This walkthrough passes only if the UI makes the trace legible enough that AJ
does not need to inspect raw JSON or code to answer:

- who responded or was blocked
- which workspace persona instance was involved
- which persona template was involved
- which directive and contract posture applied
- why the response was allowed or why the activation was blocked

If those answers still require implementer narration, `M1` is not ready to hand
off to `M2`.
