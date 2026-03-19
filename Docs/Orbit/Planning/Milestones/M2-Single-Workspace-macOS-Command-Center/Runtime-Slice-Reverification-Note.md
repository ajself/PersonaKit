# Runtime Slice Re-Verification Note

Status: Accepted
Milestone: `M2`
Owner: `senior-swiftui-engineer`
Review Ring: `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the Packet 1 re-check that the current Orbit runtime slice and local
persistence boundary still fit the first checkpoint before broader `M2` surface
work continues.

## Runtime Boundary Check

The current local Orbit runtime still fits the accepted first-checkpoint shape:

- one workspace record: `OrbitWorkspace`
- one founding roster made of participant records: `OrbitParticipant`
- one active durable thread plus messages: `OrbitConversationThread` and
  `OrbitMessage`
- one successful activation trace path: `OrbitActivationRecord` plus
  `OrbitActivationContractSnapshot`
- one blocked activation trace path: `OrbitActivationFailureRecord`

This remains minimal for the checkpoint because the room still avoids summaries,
memory reuse, multi-workspace switching, and server-backed runtime concerns.

## Persistence Boundary Check

Current local storage path remains:

- `.personakit/Orbit/orbit-workspace.json`

Current implementation re-verification:

- `Sources/Features/Studio/UI/Orbit/OrbitWorkspacePersistence.swift`
  now owns the deterministic file path plus load/save behavior
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+Persistence.swift`
  uses that helper rather than embedding path and JSON details directly in the
  view extension
- the first checkpoint still uses one deterministic JSON file rather than
  splitting runtime state across multiple files prematurely

## Sample And Default Data Check

`OrbitWorkspace.defaultWorkspace` still fits the checkpoint assumptions:

- workspace id: `orbit`
- founding roster: AJ, Samwise, ProdDoc
- one active thread
- two AI-backed collaborators with stable workspace persona anchors
- no activation-failure records in the seeded baseline

## Deterministic Proof Added

- `Tests/Features/Studio/OrbitWorkspacePersistenceTests.swift`
  verifies the workspace-local Orbit path, deterministic round-trip behavior,
  missing-file handling, and the default workspace shape

## Packet 1 Judgment

Packet 1 is strong enough to proceed because the runtime slice did not widen
silently while `M1` hardened. The current local model is richer than the earliest
checkpoint sketch, but the additional persisted contract and failure records
still serve attribution and fail-closed behavior rather than broadening product
scope.
