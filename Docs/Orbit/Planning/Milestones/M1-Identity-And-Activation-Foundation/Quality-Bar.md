# M1 Quality Bar

Status: Draft
Milestone: `M1`
Primary Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define what high-quality completion means for the identity and activation
foundation.

`M1` should make later Orbit collaboration trustworthy.
If identity and activation remain blurry, every later milestone inherits that
blur.

## Non-Negotiable Standard

`M1` is reached only when one Orbit response can be traced from trigger to
visible output with no hidden leaps.

That trace must be:

- attributable
- deterministic
- fail-closed under ambiguity
- faithful to PersonaKit-authored truth
- reviewable by both architecture and coverage owners

## Quality Attributes

### 1. Boundary Clarity

High bar:

- PersonaKit authored truth and Orbit runtime truth are clearly separated
- no runtime record quietly redefines persona policy
- no authored contract field is re-invented in Orbit without a reason

Failure signs:

- role or directive identity exists only in runtime prose
- Orbit stores policy decisions that should be resolved from PersonaKit
- runtime and authored ownership overlap without explanation

### 2. Attribution Completeness

High bar:

- the response can be traced to a workspace persona instance
- the active directive, relevant kits, authorized skills, and stop-point posture
  are inspectable
- trigger source and trigger message lineage are preserved

Failure signs:

- only the responding name is visible
- directive or authorization context is absent
- the operator cannot tell why a response happened

### 3. Fail-Closed Behavior

High bar:

- ambiguity and authorization problems block or surface clearly
- the system does not fake confidence on unresolved collaborator or contract
  state
- persistence failure does not leave a trace-less response in the UI

Failure signs:

- best-effort routing under uncertainty
- hidden fallbacks that produce unattributed output
- response visible before durable trace state exists

### 4. Trace Determinism

High bar:

- the same first-checkpoint input shape produces the same trace shape
- identifiers, ordering, and trace fields are stable enough for deterministic
  review
- no wall-clock timing or incidental state is required to understand the trace

Failure signs:

- trace fields appear opportunistically
- ordering is unstable
- the example trace cannot be used as a golden review reference

### 5. Reviewability

High bar:

- an architectural reviewer can audit the contract without guessing
- a coverage reviewer can name the exact tests needed
- the operator can inspect enough trace state to trust the feature difference

Failure signs:

- activation details are trapped in code only
- review relies on implementer explanation rather than artifacts

### 6. Validation Rigor

High bar:

- the milestone has deterministic tests for success and failure paths
- failure modes are enumerated and mapped to expected behavior
- the golden example is covered by validation, not just prose

Failure signs:

- only a happy path is tested
- ambiguous and unauthorized cases are treated as edge cases for later

## Disqualifying Shortcuts

Any of these mean `M1` is not complete:

- the system can respond without a durable activation trace
- collaborator identity still depends on unresolved `ProdDoc` ambiguity
- unauthorized or unresolved activation attempts silently fall back to generic
  response behavior
- tests prove only that something happened, not that the right identity path was
  used
- the contract is split across so many informal notes that reviewers cannot tell
  what is authoritative
- the milestone drifts into server-stack, deployment, or alternate client-stack
  choices that belong outside `M1`

## What "Impressive" Looks Like

An impressive `M1` outcome means a reviewer can inspect one response and say:

- who responded
- from what workspace identity
- under what directive and allowed skill posture
- from what trigger
- with what memory posture
- why the system was allowed to proceed
- how it would have failed if the input were ambiguous

If the result merely demonstrates a response, it is not enough.
If it demonstrates trustworthy attribution, it is.
