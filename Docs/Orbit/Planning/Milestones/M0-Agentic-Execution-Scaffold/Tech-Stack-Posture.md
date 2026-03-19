# Tech Stack Posture

Status: Accepted
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Freeze the approved technology posture for `M0` through `M3` so later AI lanes
do not treat foundational stack choices as open-ended implementation freedom.

This document exists to make the early Orbit milestones sharper, cheaper, and
less drift-prone.

## North Star For AI Lanes

AI lanes involved in Orbit implementation should build the approved product and
stack.

They should not treat planning work as permission to redefine Orbit's
foundational technology direction.

For foundational choices, the AI's job is implementation fidelity, not
architectural re-selection.

## Scope

This posture applies to:

- `M0` planning and delegation standards
- `M1` identity and activation foundation
- `M2` single-workspace macOS proving loop
- `M3` canonical Orbit Server and runtime backbone

This posture is binding for `M0` through `M3`.

After `M3`, this posture remains the binding Orbit technology direction unless AJ
explicitly supersedes it in a separate architecture decision.

Later milestone dossiers may add narrower constraints, but they must not reopen
or replace the choices frozen here.

## Current Construction Window

This planning set authorizes active construction work through `M3` only.

After `M3` closes, implementation should pause.

`M4` and later milestones remain planning material until AJ explicitly restarts
construction beyond `M3`.

## Fixed Choices

### Client direction for `M1` and `M2`

- `Swift` and `SwiftUI` for the macOS client path
- no web client for these milestones
- the current PersonaKit macOS or Studio app is a valid starting point, not a
  protected end-state

### Orbit-first product priority

- Orbit is the primary product target
- the current PersonaKit macOS app should be treated as replaceable scaffolding
  if it materially obstructs Orbit milestone delivery
- AI lanes may not protect existing app structure for sentimental or historical
  reasons

If a milestone is better served by refactoring, replacing, or removing current
PersonaKit macOS app surfaces, that is allowed within the approved worktree
execution boundary described below.

### PersonaKit client execution posture

Use the `senior-swiftui-engineer` persona when client implementation guidance is
needed.

That persona's default kits should be treated as active guidance for these
milestones:

- `repo-constraints`
- `swift-style`
- `swiftui-style`

### Server direction for `M3`

- server language: `Swift`
- server framework: `Vapor`
- `Hummingbird` is not an active candidate for `M3` and should not be revived by
  implementation lanes unless AJ explicitly reopens that decision

### Canonical runtime storage

- canonical transactional runtime store: `Postgres`
- do not prototype the canonical Orbit Server on `SQLite`

### Deployment posture

- self-hosted only
- private infrastructure only
- preferred reference topology: `Mac mini + Synology`
- the preferred topology is not a hard requirement
- no managed cloud platform in `M0` through `M3`

### Architecture posture

- monolith-first
- no microservices in `M3`
- PersonaKit contract resolution should live in the same Swift server process for
  `M3`, while remaining a logical boundary in code

## Constrained Choices

### Realtime

- leaning transport: `WebSocket`
- `SSE` is acceptable if it better preserves simplicity without weakening the
  snapshot-plus-replay model
- realtime semantics must stay subordinate to durable state

### Artifact storage

- self-hosted only
- object-style abstraction required from day one
- leaning first backend: NAS-backed filesystem
- a local filesystem-backed first implementation is acceptable only if it keeps
  the abstraction honest and the self-hosted posture intact

### Migration from `M2` to `M3`

- prefer seeded fresh server state or a re-proven server-backed flow
- do not import local proving-loop history by default

## Dependency Philosophy

- Apple-native and Swift-native first
- few dependencies
- proven boring libraries are okay when they reduce risk
- avoid heavy framework layering or trendy infrastructure abstractions
- when open-source projects are introduced, their licensing should be acceptable
  for private and commercial use

## Disallowed For `M0` Through `M3`

- cloud-managed services
- paid services
- extra infrastructure components such as `Redis`, `Kafka`, `NATS`, a separate
  queue system, a separate cache tier, or a vector or search database in the
  baseline `M3` runtime milestone
- orchestration overhead such as `Kubernetes`, service mesh, or a mandatory
  Docker-first deployment posture
- hidden autonomous background loops or silent consequential actions
- speculative forward-looking APIs that are not directly required for the active
  milestone

## Verification Posture

For `M0` through `M3`, testing and review should emphasize:

- unit tests
- integration tests
- replay and reconnect tests where relevant
- failure-path tests where relevant
- manual proof as supporting evidence only, never as sufficient evidence by
  itself

### Snapshot testing

Snapshot testing is explicitly encouraged where it helps AI lanes and reviewers
inspect:

- UI and UX continuity
- accessibility-sensitive surfaces
- durable product artifacts
- human-visible outputs that should not regress quietly

Approved direction:

- `pointfreeco/swift-snapshot-testing`

## AI Decision Boundary

AI lanes must not choose on their own:

- server framework
- database
- deployment posture
- major storage backend changes
- major realtime architecture changes
- new major dependencies

AI lanes may choose within the approved posture:

- internal module boundaries
- implementation details inside the chosen stack
- test structure and supporting test helpers
- small supporting libraries if they clearly fit the dependency philosophy

AI lanes must not use later milestone planning or implementation difficulty as a
reason to reopen these choices.

If an AI lane believes one of these choices should change, it must stop, surface
the concern explicitly, and wait for AJ to decide.

## Worktree Execution Boundary

Milestone implementation work should start in a dedicated non-main worktree on
its associated branch.

Inside that worktree, AI lanes may make repo-wide changes that are necessary to
deliver the active Orbit milestone.

That permission includes, when justified by the milestone and evidence:

- refactoring or replacing existing PersonaKit macOS app structure
- removing PersonaKit app surfaces that no longer serve the Orbit direction
- reorganizing project structure when the active milestone is better served by a
  cleaner Orbit-first shape

This permission does not authorize:

- changes on `main` in the main worktree
- redefining the approved Orbit product or stack direction
- speculative cleanup unrelated to the active milestone
- silent broadening beyond the milestone's evidence and review gates

## Git And Lane Rule

AI lanes may create commits only when AJ has authorized commits for the exact
active non-main worktree scope.

If that approval is missing or unclear, the lane must stop before committing.

AI lanes must not commit to `main` on the main worktree.

The main worktree remains protected.

Creative restructuring is allowed in the active milestone worktree, not on the
main lane.

## Quality Rule

This posture is only useful if later milestones can rely on it without reopening
settled choices through implementation drift.

If a later lane can still claim the server stack or deployment model is open, or
can treat itself as authorized to redefine them, this document has failed.
