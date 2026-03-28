# Persona Hiring Standards

Use this runtime standard when reverse-interviewing a persona candidate for a specific role.
For the full rubric and examples, see `persona-hiring-standards-reference`.

## Required Inputs

1. Candidate persona id.
2. Role context and expected outcomes.
3. Must-have capabilities.
4. Hard constraints and non-goals.

## Evidence Sources

Reverse-interview output should cite:

1. The candidate persona artifact.
2. Linked kits and essentials.
3. Relevant directives, intents, sessions, and continuity logs when history matters.

## Required Output

Each review should produce:

1. Qualification summary: `qualified`, `qualified-with-gaps`, or `not-yet-qualified`.
2. Strengths tied to role requirements.
3. Gap list with severity.
4. Missing artifact recommendations grouped by type.
5. Confidence score, threshold used, and recommended next step.

## Confidence Rule

1. Score domain, delivery, risk, collaboration, and tooling coverage.
2. Default threshold is `80` when no explicit threshold is provided.
3. If confidence is below threshold or unknowns are material, run `persona-hiring-research-loop` or stop for AJ guidance.

## Persistence And Guardrails

1. Write the human report to the hiring-review path or approved override.
2. Append the machine-readable entry to `persona-hiring-reviews.jsonl`.
3. Do not modify candidate artifacts until AJ approves the proposed changes.
