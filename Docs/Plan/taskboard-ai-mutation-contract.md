# Taskboard AI Mutation Contract

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define a deterministic, AI-safe mutation contract for Taskboard so Samwise (and
other approved agents) can read and edit board state without ambiguous behavior.

## Current baseline (from code)

1. Canonical store is workspace-local JSON at:
   `.personakit/Taskboard/taskboard.json`.
2. Board schema contains:
   - `name`
   - `nextLaneSequence`
   - `nextTicketSequence`
   - `lanes[]`
3. Lane schema contains:
   - `id`
   - `title`
   - `templateID`
   - `order`
   - `tickets[]`
4. Ticket schema contains:
   - `id`
   - `title`
   - `owner`
   - `priority`

Code source:

1. `Sources/Features/Studio/UI/TaskboardPanelView.swift`

## Contract goals

1. Deterministic outputs for identical inputs.
2. Safe conflict behavior and clear errors.
3. Minimal operation surface for v2 foundations.
4. Backward-compatible storage evolution path.

## Operation envelope (proposed)

```json
{
  "schemaVersion": 1,
  "requestId": "stable-caller-generated-id",
  "expectedBoardRevision": 12,
  "operation": {
    "type": "create_ticket",
    "payload": {}
  }
}
```

Rules:

1. `schemaVersion` is required and must be known.
2. `requestId` is required for idempotency tracking.
3. `expectedBoardRevision` is required for optimistic concurrency.
4. Unknown `operation.type` fails with deterministic `unsupported_operation`.

## Read contract (proposed)

1. `read_board` returns normalized board state plus metadata:
   - `boardRevision`
   - `schemaVersion`
   - `normalizedAtRevision`
2. Read responses are sorted and stable:
   - lanes sorted by `order`, then `id`
   - tickets stable in lane order as stored

## Mutation operations (v1 set)

1. `create_lane`
2. `edit_lane`
3. `reorder_lane`
4. `delete_lane`
5. `create_ticket`
6. `edit_ticket`
7. `move_ticket`
8. `delete_ticket`

Each operation MUST:

1. Validate referential integrity before write.
2. Return full normalized board after successful write.
3. Return stable error codes on failure.

## Determinism and normalization rules

1. Lane IDs are generated from monotonic sequence (`lane-N`).
2. Ticket IDs are generated from monotonic sequence (`ticket-N`).
3. Lane `order` is normalized to contiguous ascending values after any lane
   mutation.
4. Lane title uniqueness is case-insensitive and auto-suffixed (`"Ready 2"`)
   using existing in-app behavior.
5. Failed mutations produce no partial writes.

## Error taxonomy (proposed)

1. `unsupported_operation`
2. `schema_version_mismatch`
3. `revision_conflict`
4. `lane_not_found`
5. `ticket_not_found`
6. `validation_failed`
7. `io_persistence_failed`

Each error returns:

1. `code`
2. `message`
3. `details` (machine-parseable)
4. `boardRevision` (if known)

## Transport and surface strategy

1. Phase A (TV2-M1/M2): CLI-first contract endpoint (deterministic JSON in/out).
2. Phase B: MCP-compatible mutation tooling only after explicit policy approval.
3. MCP read-only resources remain valid context sources regardless of mutation
   pathway.

## Test plan (contract-focused)

1. Determinism:
   - identical request sequence produces byte-equivalent resulting board JSON.
2. Concurrency:
   - stale `expectedBoardRevision` fails with `revision_conflict`.
3. Referential integrity:
   - moving ticket to missing lane fails with no write.
4. Idempotency:
   - duplicate `requestId` does not duplicate effect.
5. Normalization:
   - lane reorder always normalizes `order` to contiguous values.

## Open decisions for AJ lock

1. Keep JSON file as canonical store for v2, or introduce SQLite adapter now?
2. Require `requestId` in all mutation calls from first implementation, or phase
   it in after initial CLI path?
3. Should `read_board` include derived analytics fields or remain raw canonical
   state only?

## Related docs

1. [Taskboard V2 Initiative Plan](./taskboard-v2-initiative-plan.md)
2. [Taskboard V2 Feature Lock](./taskboard-v2-feature-lock.md)
3. [Taskboard Trello Gap Matrix](../Research/taskboard-trello-gap-matrix.md)
