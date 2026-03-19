# Addressing And Lightweight Exchange Re-Proof Note

Status: Accepted
Milestone: `M2`
Owner: `senior-swiftui-engineer`
Review Ring: `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Record the Packet 4 re-proof that direct address and lightweight
multi-participant exchange remain intentional, narrow, and reviewable.

## Direct Address Re-Proof

Current direct-address path:

- AJ targets one visible AI-backed collaborator explicitly
- Orbit routes the turn to that collaborator only
- the response is persisted as `directAddress`
- the room keeps one attributable collaborator response with no hidden fan-out

Visible room proof:

- the composer now explains direct collaborator routing before the turn is sent
- participant responses show `Direct Address` as a visible route cue in the room

## Lightweight Exchange Re-Proof

Current lightweight-meeting path:

- AJ invites the founding group explicitly
- Orbit records one meeting system event
- Orbit routes the same turn to the visible AI-backed collaborators only
- the resulting responses remain in one shared thread and persist as
  `meetingInvocation`

Visible room proof:

- the composer explains that this is a lightweight exchange, not a hidden engine
- participant responses show `Lightweight Meeting` as a visible route cue in the
  room

## Why The Response Bridge Is Still Narrow

`OrbitParticipantResponseBridge.swift` still does only three routing decisions:

1. current thread reply
   one explicit room-steward response path
2. direct address
   one explicitly named collaborator only
3. founding-group invitation
   the visible AI-backed collaborators only, plus one meeting system event

It does not:

- orchestrate hidden sub-threads
- choose among multiple invisible agents
- create extra routing layers outside the room thread
- widen into summary, memory, or server behavior

## Deterministic Proof Added

- `OrbitWorkspaceTests.directAddressCreatesParticipantResponseAndActivationTrace`
- `OrbitWorkspaceTests.foundingGroupInvitationCreatesMeetingEventAndMultipleResponses`
- `OrbitSnapshotTests.testOrbitDirectAddressConversation`
- `OrbitSnapshotTests.testOrbitMeetingConversation`

## Packet 4 Judgment

Packet 4 is strong enough to proceed because the room now makes direct address
and lightweight exchange more visible from the product surface while keeping the
underlying response bridge narrow and inspectable.
