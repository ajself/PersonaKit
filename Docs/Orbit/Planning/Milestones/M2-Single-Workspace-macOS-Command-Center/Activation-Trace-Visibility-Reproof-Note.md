# Activation Trace Visibility Re-Proof Note

Status: Ready For Planning Closeout
Milestone: `M2`
Owner: `senior-swiftui-engineer`
Review Ring: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the Packet 5 re-proof that Orbit trace visibility is discoverable from the
product surface, useful for review, and light enough not to take over the room.

## Product-Surface Trace Affordance

Current room behavior:

- participant responses show a visible route cue such as `Direct Address`,
  `Current Thread`, or `Lightweight Meeting`
- blocked system events show a visible `Why blocked?` affordance
- trace detail is available through lightweight disclosure from the message card,
  not through debug-only tooling

This keeps trace discoverable while avoiding always-open metadata blocks under
every message.

## Mapping To Durable Runtime State

Visible trace affordance maps to persisted records as follows:

- `Why this response?`
  expands from `OrbitActivationRecord` plus `OrbitActivationContractSnapshot`
- `Why blocked?`
  expands from `OrbitActivationFailureRecord`

The room-level UI therefore exposes the same durable attribution records used by
validation, rather than a parallel debug-only explanation path.

## Weight And Clarity Judgment

- lighter than the always-open `M1` trace block
- still visible enough that AJ can discover why a response happened from the room
- specific enough to answer participant, directive, route, contract, and blocked
  failure questions when expanded

## Snapshot Proof

- `OrbitSnapshotTests.testOrbitDirectAddressTraceExpanded`
- `OrbitSnapshotTests.testOrbitDirectAddressConversation`
- `OrbitSnapshotTests.testOrbitMeetingConversation`

These snapshots prove both the lightweight collapsed affordance and one expanded
trace readout from the product surface.

## Packet 5 Judgment

Packet 5 is strong enough to proceed because trace inspection is now visibly part
of the Orbit room model without dominating first-open composition.
