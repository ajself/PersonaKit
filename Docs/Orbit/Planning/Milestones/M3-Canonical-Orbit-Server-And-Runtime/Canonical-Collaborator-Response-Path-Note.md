# Canonical Collaborator Response Path Note

Status: Ready For Planning Closeout
Milestone: `M3`
Owner: `studio-integration-coordinator`
Review Ring: `architectural-editor`, `studio-reliability-engineer`, `venture-product-steward`
Last Updated: 2026-03-18

## Purpose

Record the first server-driven collaborator response slice for the canonical room.

## What Exists Now

- `OrbitPhase1CollaboratorResponseService`
- `OrbitGatewayAppendCollaboratorResponseRequest`
- `OrbitGatewayAppendCollaboratorResponse`
- `POST /api/orbit/room/responses`

These now exist across:

- `Sources/Features/OrbitServerRuntime/Phase1CollaboratorResponseService.swift`
- `Sources/Features/OrbitServerGateway/OrbitGatewayPayloads.swift`
- `Sources/Features/OrbitServerGateway/OrbitGatewayRoutes.swift`

## Current Responsibilities

The collaborator-response path now provides:

1. load the canonical room by workspace and channel scope
2. validate the target workspace persona and trigger message
3. append one server-owned collaborator response message
4. persist persona activation linkage, agent-run linkage, and post-event evidence
5. emit durable realtime events for the response path

## Why This Matters

- `M3` no longer proves only user-authored writes through the server
- the canonical room can now represent a collaborator response path with runtime
  attribution on the server side
- the event log now covers more than bootstrap and user-message append semantics

## Deterministic Proof

- `Tests/Features/OrbitServer/Phase1CollaboratorResponseServiceTests.swift`
- `Tests/Features/OrbitServer/OrbitServerGatewayTests.swift`

Current proof covers:

- missing workspace-persona failure behavior
- missing trigger-message failure behavior
- canonical collaborator response creation
- activation/run linkage persistence contract
- live gateway response-route request/response behavior

## Honest Limit

This slice still does not prove a full end-to-end server-driven response loop in
the macOS UI.

It does prove that the canonical runtime can now own the collaborator response
write path instead of treating it as future-only work.

## Packet Judgment

The canonical collaborator response path is now materially underway because the
server runtime can persist both sides of the room conversation with linked
activation evidence.
