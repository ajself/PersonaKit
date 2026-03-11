# Squad Planning Log Contract

Use this essential when recording durable outputs from
`samwise-squad-planning` planning passes.

## Canonical Paths

1. Human report directory:
   - `Docs/PersonaKit/Development/planning-reviews/`
2. Machine log file:
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
3. Machine schema file:
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.schema.json`

## Required JSONL Fields

Each log entry should include:

1. `entryId` (`SPR-0001` style stable ID)
2. `date` (`YYYY-MM-DD`)
3. `sessionId` (`samwise-squad-planning`)
4. `objective`
5. `workspaceScope`
6. `scopeBoundary`
7. `reportPath`
8. `roleAssignments` (array)
9. `missingArtifacts` (grouped by artifact type)
10. `firstCheckpoint`
11. `definitionOfDone` (array)
12. `validationOwner`
13. `validationCommands` (array)
14. `validationStatus`
15. `handoffStatus`
16. `nextSessionId`
17. `reviewer`

Recommended:

1. `relatedHiringReviewIds`
2. `details`
3. `delegatedRoleNames`
4. `delegatedHandoffs`

## Delegated Handoff Details

When a planning pass expects a role to be staffed by a spawned agent, record
that role in `delegatedRoleNames` and include a matching machine-readable
handoff object in `delegatedHandoffs`.

Each `delegatedHandoffs` item should include:

1. `role`
2. `ownerRef`
3. `requiredSessionId` or `requiredDirectiveId`
4. `groundingMode`
5. `fallbackArtifactPaths`
6. `writeScope`
7. `validationCommands`
8. `failureDisposition`
9. `groundingSourcePath`
10. `snapshotDate` when `groundingMode = static-export`
11. `snapshotRevision` when one exists

## Review Status Rule

1. Every planning pass should append one new log entry; do not overwrite prior
   rows.
2. If a planning pass identifies execution-critical role gaps, the entry should
   route the next session to a hiring or remediation loop before execution.
3. The human-readable report and JSONL entry should agree on the named next
   session, first checkpoint, and validation owner.
4. When delegated handoffs are present, the report and JSONL entry should agree
   on delegated role names, grounding mode, failure disposition, and
   static-export provenance fields.

## Guardrails

- Keep IDs deterministic and monotonic.
- Keep role-assignment coverage explicit; do not omit missing roles from the
  log.
- Use `relatedHiringReviewIds` whenever reverse-interview output informed the
  planning pass.
- Keep execution handoff blocked until review gates, definition-of-done, and
  validation expectations are explicit.
- Keep delegated work blocked until each spawned-agent role has an explicit
  grounding path or a recorded `grounding-blocked` disposition.
- When delegated roles are declared, machine-readable delegated handoff records
  are required; do not rely on prose-only reports.

## Validation

Run:

- `Scripts/check-squad-planning-logs.sh`
