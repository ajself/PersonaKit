# Taskboard Parity Designer Reverse Interview

Status: Complete
Owner: AJ
Last Reviewed: 2026-03-08

Session: `samwise-persona-hiring`
Candidate: `taskboard-parity-designer`

## Role Context And Required Capabilities

Assess whether `taskboard-parity-designer` is qualified to judge whether
Taskboard board and card flows visually and behaviorally feel credibly
Trello-like for this initiative.

Must-have capabilities:

1. Strong board and card parity judgment grounded in explicit reference criteria.
2. Severity-based review output with blocker, major, and minor findings.
3. Clear rejection of vague taste-only critique.
4. Ability to keep parity claims bounded to board and card scope.
5. Hand-off quality strong enough for Samwise and the squad lead to act on.

## Evidence References

1. `.personakit/Packs/personas/taskboard-parity-designer.persona.json`
2. `.personakit/Packs/intents/review-taskboard-board-card-parity.intent.json`
3. `.personakit/Packs/directives/review-taskboard-board-card-parity.directive.json`
4. `.personakit/Sessions/taskboard-parity-design-review.session.json`
5. `.personakit/Packs/kits/taskboard-parity-core.kit.json`
6. `.personakit/Packs/kits/interaction-quality-core.kit.json`
7. `.personakit/Packs/essentials/taskboard-board-card-parity-checklist.md`
8. `Docs/Plan/taskboard-trello-parity-execution-charter.md`

## Strengths

1. Persona responsibilities center on parity judgment instead of vague design inspiration.
2. Non-goals explicitly forbid product-scope creep and unsupported taste claims.
3. Intent and directive require explicit parity references and severity-tagged findings.
4. Default kits provide both the parity checklist and deterministic interaction-quality reporting surfaces.
5. The role is well matched to the Visual QA Squad without overlapping persistence or architecture ownership.

## Gaps By Severity

- Medium: The role does not yet have a dedicated benchmark-case corpus for visual parity calibration across repeated passes.
- Low: First-run judgments will still benefit from Samwise cross-checking until a few real parity reviews exist.

## Unknowns And Assumptions

1. Assumption: Trello research artifacts remain the source of truth for parity references.
2. Unknown: whether future parity review needs a richer image-annotation workflow than the current report template.

## Confidence Score And Threshold

- Domain understanding: `4/5`
- Delivery planning quality: `4/5`
- Risk and guardrail discipline: `5/5`
- Collaboration and handoff clarity: `4/5`
- Tooling and workflow coverage: `5/5`

Total: `22/25`
Confidence: `88%`
Threshold: `80%`

## Verdict

`qualified`

Rationale: the candidate has enough domain shape, parity-specific guardrails,
and reporting discipline to operate now as the Trello-parity review specialist
for this initiative.

## Missing Artifact Recommendations By Type

- essentials: `taskboard-parity-benchmark-cases` (future calibration only)
- kits: none required
- intents: none required
- directives: none required
- sessions: none required

## First Implementation Step

Run `taskboard-parity-design-review` after the next Taskboard interaction slice
and require explicit blocker, major, and minor findings tied to the parity
checklist before claiming parity progress.
