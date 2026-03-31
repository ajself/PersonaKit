# Taskboard AI Mutation Contract

Status: Parked
Owner: AJ  
Last Reviewed: 2026-03-29

## Purpose

Define a deterministic, AI-safe mutation contract for Taskboard so Samwise (and
other approved agents) can read and edit board state without ambiguous behavior.

Historical posture:

- preserved as the Taskboard AI-editability contract for the parked initiative
- not the current repo-wide execution queue
- current repo-wide priority lives in `Docs/Current-State.md`

## Current baseline (from code)

1. Canonical store is workspace-local JSON at:
   `.personakit/Taskboard/taskboard.json`.
2. Board schema contains:
   - `name`
   - `nextLaneSequence`
   - `nextTicketSequence`
   - `nextChecklistSequence`
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
   - `labels[]`
   - `dueDateISO8601` (`YYYY-MM-DD` date-only)
   - `checklist[]`

Code source:

1. `Sources/Features/Studio/UI/Taskboard/TaskboardPanelView.swift`
2. `Sources/Features/Studio/UI/Taskboard/TaskboardModels.swift`
3. `Sources/Features/Studio/UI/Taskboard/TaskboardDrafts.swift`
4. `Sources/Features/Studio/UI/Taskboard/TaskboardMutationEngine.swift`
5. `Sources/Features/Studio/UI/Taskboard/TaskboardSearchEngine.swift`

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

## Locked decisions (M2A kickoff)

1. Canonical store remains workspace-local JSON for v2 (`.personakit/Taskboard/taskboard.json`).
2. `requestId` is required for all mutation calls from the first implementation.
3. `read_board` returns canonical normalized state only; derived analytics remain
   out-of-band and optional for future endpoints.

## Decision log

| Date | Decision | Rationale | Approved By |
| --- | --- | --- | --- |
| 2026-03-07 | Keep JSON as canonical store for v2 | Fastest path with lowest migration risk while mutation contract stabilizes | AJ + Samwise |
| 2026-03-07 | Require `requestId` from v1 | Enables deterministic idempotency and safer AI retries | AJ + Samwise |
| 2026-03-07 | Keep `read_board` canonical-only | Prevents ambiguity between persisted truth and derived view data | AJ + Samwise |

## Related docs

1. [Taskboard V2 Initiative Plan](./taskboard-v2-initiative-plan.md)
2. [Taskboard V2 Feature Lock](./taskboard-v2-feature-lock.md)
3. [Taskboard Trello Gap Matrix](../Research/taskboard-trello-gap-matrix.md)
