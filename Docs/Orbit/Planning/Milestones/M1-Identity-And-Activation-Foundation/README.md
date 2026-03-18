# M1 Identity And Activation Foundation

Status: Planned
Primary Owner: `architectural-editor`
Supporting Personas: `senior-swiftui-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Make one Orbit response fully attributable before collaboration expands.

## Quality Standard

`M1` is not successful because a response technically renders.

`M1` is successful only when the response is attributable, inspectable,
deterministic, and correctly bounded by the authored PersonaKit contract.

The bare minimum is not a milestone win.
If the response path is brittle, blurry, or under-tested, `M1` has not been
reached.

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Quality-Bar.md`
  definition of impressive `M1` quality and disqualifying shortcuts
- `Identity-And-Activation-Contract.md`
  first-checkpoint contract for identity ownership and activation sequencing
- `Activation-Trace-Golden-Example.md`
  one deterministic example of a correct first-checkpoint response trace
- `Failure-Matrix.md`
  fail-closed behavior for ambiguity, authorization, and persistence problems
- `Validation-And-Review-Matrix.md`
  deterministic validation plan and owner-specific review matrix
- `Evidence-And-Exit-Criteria.md`
  milestone-close rules and proof requirements

## Preconditions

- `M0` is closed or explicitly waived for this milestone
- the `ProdDoc` naming decision is frozen for the first checkpoint
- the planning stack for `M1` and `M2` is aligned

## Scope Freeze

In scope:

- workspace persona instance model
- collaborator identity model
- activation sequence
- activation trace records
- failure handling for ambiguous targeting or unauthorized activation

Out of scope:

- broad UI design work beyond inspectability needs
- teams and squads
- server migration
- server framework or deployment changes
- memory candidate review or memory reuse

## Required Inputs

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Tech-Stack-Posture.md`
- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`

## Implementation Posture

- start from the current macOS app surfaces, but do not treat them as protected
  end-state structure
- use `Swift` and `SwiftUI` for any client-facing first-checkpoint work
- use the `senior-swiftui-engineer` persona with the `repo-constraints`,
  `swift-style`, and `swiftui-style` kits when client-surface changes or reviews
  are needed
- AI lanes in `M1` should build inside the approved client posture, not redefine
  it
- in a dedicated non-main worktree, AI lanes may refactor or replace current app
  surfaces if that materially improves Orbit's identity and activation foundation
- do not reopen server stack, deployment, or backend framework decisions in `M1`

## Execution Packets

### Packet 1. Boundary Audit

Outcome:

- authored truth and runtime truth are explicitly separated in the first
  checkpoint design

Work:

- audit current docs and code seams against RFC-0001 and RFC-0003
- list every field that belongs to PersonaKit versus Orbit runtime
- identify any first-checkpoint drift from the authored/runtime split

Done when:

- one boundary note exists and later packets can reference it without guessing

### Packet 2. Workspace Persona And Collaborator Model

Outcome:

- first-checkpoint participant records map cleanly to workspace persona identity

Work:

- define workspace persona instance expectations
- define human participant versus AI-backed collaborator behavior
- define how the founding roster maps to runtime records

Done when:

- every visible AI-backed participant in the first checkpoint has a stable
  identity anchor

### Packet 3. Activation Trace Contract

Outcome:

- the first checkpoint knows exactly what must be persisted for a response trace

Work:

- define activation fields that must exist
- define contract snapshot expectations
- define activation-memory-source linkage behavior for the first checkpoint,
  including the no-memory case

Done when:

- one response trace example can be written and inspected deterministically

### Packet 4. Failure Modes And Guardrails

Outcome:

- the first checkpoint fails closed instead of fabricating certainty

Work:

- define ambiguous workspace failure
- define ambiguous collaborator failure
- define missing directive or unauthorized skill failure
- define how those failures surface without silently continuing

Done when:

- a written failure matrix covers all first-checkpoint activation edges

### Packet 5. Validation Suite Design

Outcome:

- `M2` can build on a stable activation contract rather than retrofitting tests

Work:

- define deterministic tests for activation attribution
- define tests for ambiguity and unauthorized paths
- define one golden activation trace example for review

Done when:

- the validation owner can state exactly what must pass before `M2` broadens UI

## Subagent Use Pattern

Safe subagents:

- RFC-0001 trace audit
- RFC-0003 identity-boundary audit
- failure-mode matrix review
- deterministic test design review

Avoid:

- parallel implementation across multiple runtime seams before the boundary audit
  lands

## Evidence Package

- boundary audit note
- first-checkpoint identity model note
- activation trace example
- failure matrix
- validation checklist for activation semantics

## Stop Points

- stop if authored/runtime ownership becomes blurry
- stop if collaborator identity depends on unresolved `ProdDoc` naming
- stop if activation inspectability is being treated as optional metadata

## Exit And Handoff

Exit when one response can be traced end to end and the coverage owner signs off
on the required validation set.

Handoff forward to:

- `M2` for the command-center proving loop
- `M3` as the identity contract baseline for server migration
