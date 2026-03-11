# Worktree Squad Pattern Decision

- Date: `2026-03-11`
- Objective: Decide whether the worktree-squad model should become standard or
  remain situational after two PersonaKit trials.
- Reviewer: `Samwise`
- Trials:
  - `Trial 1`: generated workstream docs pipeline
  - `Trial 2`: subagent grounding and handoff refinement

## Evidence Packet

1. `Docs/PersonaKit/Development/retrospectives/worktree-squad/2026-03-11-generated-workstream-docs-retrospective.md`
2. `Docs/PersonaKit/Development/retrospectives/worktree-squad/2026-03-11-subagent-grounding-handoff-retrospective.md`
3. `Docs/PersonaKit/Development/planning-reviews/2026-03-11-subagent-grounding-handoff-plan.md`
4. `Docs/PersonaKit/Development/partner-context-log.md`

## Comparison Scorecard

| Category | Trial 1 | Trial 2 | Notes |
| --- | --- | --- | --- |
| Scope control | `strong yes` | `strong yes` | Explicit stop points and bounded edit surfaces materially prevented drift in both trials. |
| Role clarity | `mixed` | `strong yes` | Trial 1 roles mostly clarified review seams; Trial 2 roles more clearly separated planning, maintenance, and contract review. |
| Gate value | `strong yes` | `strong yes` | Gates sharpened the generated/manual doc boundary in Trial 1 and the MCP-first fallback ladder in Trial 2. |
| Parallelism reality | `no` | `mixed` | Trial 1 stayed sequential around one shared core path; Trial 2 still leaned sequential, but role separation improved the process boundary work. |
| Overhead cost | `mixed` | `mixed` | The process cost was acceptable, but higher than a simple lane would have needed for straightforward delivery. |
| Reusability | `mixed` | `strong yes` | Trial 1 produced a narrow generator pattern; Trial 2 produced broader reusable planning-stack guidance. |

## Outcome

- Recommendation: `situational`

## Why

1. Both trials proved that squads add real value when the main risk is boundary
   drift, source-of-truth ambiguity, or cross-role review discipline.
2. Neither trial proved that medium complexity alone creates useful
   multi-lane parallelism.
3. Trial 2 was the stronger process signal: the squad model materially helped a
   planning-stack contract change that spanned planning review, active
   contracts, templates, log guidance, and maintenance discipline.
4. That evidence supports a situational rule more than a repo-wide default.

## Decision

1. Use `worktree-squad` by default only when the main risk is:
   - boundary-heavy coordination
   - source-of-truth ambiguity
   - review-sensitive process or contract hardening
2. Prefer a simpler lane when the work is mostly:
   - straight-through implementation
   - tightly coupled to one shared core path
   - unlikely to benefit from explicit multi-role gates
3. Revisit this decision only after a future trial materially contradicts the
   current situational result.

## Follow-Up Actions

1. Item: Apply the situational rule to the next medium-complexity assignment before staffing it.
   - Owner: Samwise
   - Checkpoint: before the next new squad-planning review is finalized
   - Success signal: the next plan explicitly justifies squad versus simple-lane selection
2. Item: Use the duplicate-ID guarantees brief as the first real test of the situational rule if it proceeds.
   - Owner: AJ + Samwise
   - Checkpoint: before any duplicate-ID implementation handoff begins
   - Success signal: the checkpoint states whether the main risk is boundary discipline or straight-through delivery
3. Item: Mine both trial retrospectives for a reusable squad-selection heuristic.
   - Owner: Rosie
   - Checkpoint: next retrospective-gardening pass
   - Success signal: future recommendations distinguish squad value from parallelism value
