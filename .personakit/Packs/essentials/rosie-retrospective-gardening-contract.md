# Rosie Retrospective Gardening Contract

Use this essential when Rosie gardens Samwise diary entries and squad
retrospective artifacts.

## Inputs

1. `Docs/PersonaKit/Development/logs/samwise-diary.jsonl`
2. `Docs/PersonaKit/Development/logs/worktree-squad-loops.jsonl`
3. `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.jsonl`
4. `Docs/PersonaKit/Development/retrospectives/worktree-squad/*.md`

## Outputs

1. Recommendation report:
   - `Docs/PersonaKit/Development/retrospectives/worktree-squad/recommendations/YYYY-MM-DD-rosie-recommendations.md`
2. Recommendation JSONL entry:
   - append to `Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.jsonl` with
     `entryType = recommendation`

## Required Recommendation Sections

1. Recurring wins to preserve.
2. Recurring failures or bottlenecks.
3. Open questions to resolve next.
4. Prioritized improvement actions for next iteration cycle.
5. Owner and checkpoint for each action.

## Guardrails

1. Recommendations are proposal-first; no non-trivial changes are applied
   without AJ review.
2. Keep recommendations bounded and linked to explicit evidence.
3. Do not rewrite unrelated packs/sessions while performing retrospective
   gardening.
