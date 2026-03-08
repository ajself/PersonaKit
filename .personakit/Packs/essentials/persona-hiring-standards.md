# Persona Hiring Standards

Use this essential when reverse-interviewing a persona candidate for a specific line of work.

## Purpose

1. Evaluate whether a candidate persona is qualified for the target role.
2. Identify capability gaps and operational risks before assigning work.
3. Recommend missing PersonaKit artifacts needed to make the candidate effective.
4. Keep hiring decisions traceable, reviewable, and bounded.

## Required Inputs

1. Candidate persona ID.
2. Role context and expected outcomes.
3. Must-have capabilities for the role.
4. Hard constraints and non-goals for the role.

Optional but recommended:

1. Confidence threshold (defaults to `80` if omitted).
2. Explicit report path override.

## Evidence Requirements

Reverse-interview output must cite evidence from:

1. Candidate persona artifact.
2. Candidate-linked kits and essentials.
3. Candidate-linked directives, intents, and sessions.
4. Relevant planning or continuity logs when role history matters.

## Reverse-Interview Questions

1. Domain Fit: Can this persona reason about the target domain with enough depth?
2. Delivery Fit: Can this persona break work into bounded, reviewable increments?
3. Risk Fit: Can this persona enforce stop points, approvals, and guardrails?
4. Collaboration Fit: Can this persona produce clear handoffs and status updates?
5. Tooling Fit: Are required skills, intents, directives, and sessions available?

## Output Contract

Each reverse-interview should produce:

1. Qualification summary (`qualified`, `qualified-with-gaps`, or `not-yet-qualified`).
2. Strengths list tied to role requirements.
3. Gap list with severity (`high`, `medium`, `low`).
4. Missing artifact recommendations grouped by type:
   - essentials
   - kits
   - intents
   - directives
   - sessions
5. Recommended first implementation step to close the top gap.

Required sections:

1. Evidence references.
2. Unknowns and assumptions.
3. Confidence score and threshold used.

## Confidence Rubric

Score each dimension from `0-5` and include rationale:

1. Domain understanding.
2. Delivery planning quality.
3. Risk and guardrail discipline.
4. Collaboration and handoff clarity.
5. Tooling/workflow coverage.

Confidence score:

1. `totalScore = sum(dimensions)` (max `25`)
2. `confidencePercent = (totalScore / 25) * 100`

Verdict guidance:

1. `>= 80`: `qualified` (or `qualified-with-gaps` if any high-severity gap remains)
2. `60-79`: `qualified-with-gaps`
3. `< 60`: `not-yet-qualified`

Default threshold rule:

1. If `confidenceThreshold` is not provided, use `80`.

## Low-Confidence Protocol

If confidence is below threshold or unknowns are material:

1. Declare low confidence explicitly.
2. Run `persona-hiring-research-loop`.
3. Re-score after research.
4. If still low confidence, report missing information and stop for AJ guidance.

## Persistence Requirements

Reverse-interview outputs must be stored in both formats:

1. Human report:
   - `Docs/Development/hiring-reviews/YYYY-MM-DD-<personaId>.md`
   - or approved override path if explicitly provided
2. Machine-readable log entry:
   - append one JSON object to `Docs/Development/logs/persona-hiring-reviews.jsonl`
   - validate fields against `Docs/Development/logs/persona-hiring-reviews.schema.json`

## Guardrails

- Do not modify candidate artifacts until AJ approves proposed changes.
- Keep recommendations specific and minimally scoped.
- Do not convert hiring analysis into broad implementation without review.
- Respect active commit authorization policy.
