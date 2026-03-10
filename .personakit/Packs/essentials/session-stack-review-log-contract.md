# Session Stack Review Log Contract

Use this essential when persisting durable outputs from
`samwise-session-stack-review`.

## Canonical Paths

1. Human review directory:
   - `Docs/PersonaKit/Development/session-reviews/`
2. Machine log file:
   - `Docs/PersonaKit/Development/logs/session-stack-reviews.jsonl`
3. Machine schema file:
   - `Docs/PersonaKit/Development/logs/session-stack-reviews.schema.json`

Default review artifact naming:

1. `YYYY-MM-DD-<normalized-session-id>.md`

## Required JSONL Fields

Each review entry should include:

1. `entryId` (`SSR-0001` style stable id)
2. `date` (`YYYY-MM-DD`)
3. `sessionId` (`samwise-session-stack-review`)
4. `objective`
5. `targetSessionId`
6. `sourceRefType`
   - `id`
   - `path`
7. `reportPath`
8. `currentOverallConfidence`
9. `projectedOverallConfidence`
10. `verdict`
    - `safe`
    - `caution`
    - `unsafe`
    - `blocked`
11. `blockerCount`
12. `mcpStatus`
    - `pass`
    - `gap`
    - `unavailable`
13. `reviewer`

Recommended:

1. `details`

## Persistence Rules

1. Every review pass should write one human-readable review artifact.
2. Every persisted review should append one new JSONL entry; do not overwrite
   prior rows.
3. If the review is blocked by MCP availability or MCP capability gaps, persist
   the bounded MCP-gap artifact and record:
   - `verdict: blocked`
   - `mcpStatus: gap` or `unavailable`
4. The review artifact and JSONL entry should agree on:
   - normalized target session id
   - verdict
   - current/projected confidence, when confidence was actually earned
   - MCP status

## Guardrails

- Keep IDs deterministic and monotonic.
- Do not assign fake confidence when MCP-first review steps were blocked.
- Keep blocker count explicit instead of hiding blockers inside narrative prose.
- Prefer one durable report per review pass over thread-only conclusions.

## Validation

Run:

- `Scripts/check-session-stack-review-logs.sh`
