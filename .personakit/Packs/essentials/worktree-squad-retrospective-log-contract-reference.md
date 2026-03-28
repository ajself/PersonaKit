# Worktree Squad Retrospective Log Contract

Use this essential when recording closeout retrospectives and recommendation
entries for worktree squad iterations.

## Canonical Paths

1. Human retrospectives:
   - `Docs/PersonaKit/Development/retrospectives/worktree-squad/`
2. Retrospective stream:
   - `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.jsonl`
3. Retrospective schema:
   - `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.schema.json`

## Required Retrospective Fields

Each retrospective/recommendation entry should include:

1. `entryId` (`WSR-0001` style)
2. `date` (`YYYY-MM-DD`)
3. `sessionId`
4. `entryType` (`retrospective` or `recommendation`)
5. `objective`
6. One of these retrospective shapes:
   - `Starfish`
     - `keepDoing` (array)
     - `lessOf` (array)
     - `moreOf` (array)
     - `stopDoing` (array)
     - `startDoing` (array)
   - `Legacy`
     - `whatWentWell` (array)
     - `whatDidNot` (array)
     - `openQuestions` (array)
     - `improvements` (array)
7. `actionItems` (array)
8. `reportPath`
9. `reviewer`

Recommended when the active session's directive carries workstream metadata:

1. `workstream`
   - `id`
   - `phase`
   - `currentSessionId`
   - `entrySessionId`
   - `nextSessionIds`
   - `requiredCloseoutSessionId`

## Strict Fields For New Retrospectives

New `worktree-squad-retrospective` entries should also include:

1. `retrospectiveMethod`
   - `roundtable`
   - `fan-out`
   - `hybrid`
2. `declaredRoles` (array)
   - the roles or personas the run expected to involve
3. `actualParticipants` (array)
   - the roles or personas that actually contributed evidence
4. `participantEvidencePaths` (array)
   - raw participant artifacts, pass outputs, or minutes used to support the
     retrospective
5. `subagentCount` (integer)
   - the number of sub-agents actually used during the evaluated run
6. `featureConfidence`
   - `low`, `medium`, or `high`
7. `productConfidence`
   - `low`, `medium`, or `high`
8. `processConfidence`
   - `low`, `medium`, or `high`

Use these fields to separate:

- what the feature proved
- what the product review proved
- what the process actually proved

## Guardrails

1. Keep IDs deterministic and monotonic.
2. Do not overwrite prior entries; append only.
3. If `entryType` is `recommendation`, include explicit owner names in
   `actionItems`.
4. New retrospective entries should use the `Starfish` shape by default.
5. New retrospective entries should make declared roles, actual participants,
   and participant evidence explicit; planned roles do not count as active
   participation.
6. If a retrospective claims a `fan-out` or `hybrid` method, the participant
   evidence must show more than one active participant.
7. Legacy entries remain valid for historical continuity and should not be
   rewritten just to satisfy the newer format.
8. Retrospective reports should map directly to JSONL fields.
9. When `workstream` is present, it should agree with the active `sessionId`
   and any next-session routing implied by the directive's workstream edges.
10. Projected `workstream` fields are derived visibility only; directive-owned
    routing metadata remains the source of truth.

## Example Entry Shape

Use this as a model for new `worktree-squad-retrospective` entries:

```json
{
  "entryId": "WSR-0004",
  "date": "2026-03-09",
  "sessionId": "worktree-squad-retrospective",
  "entryType": "retrospective",
  "objective": "Compare Orbit retrospective methods and adopt a default closeout path.",
  "retrospectiveMethod": "hybrid",
  "declaredRoles": [
    "Samwise",
    "Senior SwiftUI Engineer",
    "Venture Product Steward",
    "Studio Interaction Quality Lead",
    "Studio Coverage Architect"
  ],
  "actualParticipants": [
    "Samwise",
    "Senior SwiftUI Engineer",
    "Venture Product Steward",
    "Studio Interaction Quality Lead",
    "Studio Coverage Architect"
  ],
  "participantEvidencePaths": [
    "Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-fan-out.md",
    "Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-roundtable.md"
  ],
  "subagentCount": 4,
  "featureConfidence": "high",
  "productConfidence": "medium",
  "processConfidence": "medium",
  "keepDoing": [
    "Keep bounded checkpoint scope."
  ],
  "lessOf": [
    "Less confidence inflation."
  ],
  "moreOf": [
    "More explicit participant accounting."
  ],
  "stopDoing": [
    "Stop treating planned roles as active participation."
  ],
  "startDoing": [
    "Start using hybrid closeout for persona-sensitive checkpoints."
  ],
  "actionItems": [
    "Owner: Samwise - Update execution docs to require hybrid closeout before the next rerun."
  ],
  "reportPath": "Docs/Orbit/Execution/retrospectives/RoundTable.md",
  "reviewer": "Samwise"
}
```

## Validation

Run:

- `Scripts/check-worktree-squad-logs.sh`
