# Persona Hiring Review: venture-product-steward

Date: 2026-03-07  
Session: `samwise-persona-hiring`  
Reviewer: AJ

## Role Context And Required Capabilities

Role context: Evaluate whether `venture-product-steward` is qualified to serve as a venture-style product manager persona for advancing PersonaKit macOS features, planning work, and tracking execution state.

Required capabilities:

1. Product discovery and opportunity framing.
2. Prioritization and roadmap sequencing.
3. Risk-aware milestone planning and status communication.
4. Translation of product decisions into concrete PersonaKit artifacts.
5. Operational continuity across planning cycles.

## Evidence References

1. `.personakit/Packs/personas/venture-product-steward.persona.json:7`
2. `.personakit/Packs/personas/venture-product-steward.persona.json:13`
3. `.personakit/Packs/personas/venture-product-steward.persona.json:20`
4. `.personakit/Packs/kits/repo-constraints.kit.json:6`
5. `.personakit/Packs/essentials/persona-hiring-standards.md:62`
6. `.personakit/Packs/essentials/persona-hiring-research-loop.md:14`
7. `.personakit/Packs/essentials/persona-hiring-calibration-playbook.md:27`
8. `.personakit/Packs/directives/reverse-interview-persona-candidate.directive.json:11`

## Strengths

1. Clear product-framing responsibilities (problem, scope, outcomes, prioritization).
2. Values align with venture/product practice (`outcomes over output`, `small bets, fast learning`).
3. Non-goals include anti-scope-creep and anti-implementation-before-framing constraints.
4. Has repository constraints baseline via `repo-constraints` kit.

## Gaps By Severity

- High: No dedicated product-management kit yet (feature brief template, roadmap format, milestone/status model, and decision-gate conventions are not bundled).
- High: No dedicated directives/sessions for discovery, planning, and tracking loops, so execution ergonomics are under-specified.
- Medium: Lacks explicit quality gates for validating product artifacts before handoff to engineering personas.
- Low: Confidence on PM-specific depth is dependent on future calibration cases because benchmark corpus is still minimal.

## Unknowns And Assumptions

Unknowns:

1. Whether this persona’s current wording is sufficient for sustained roadmap operations over multiple cycles.
2. How consistently different assessors would score this candidate without a broader benchmark set.

Assumptions:

1. AJ wants this persona optimized for PersonaKit macOS product planning first.
2. Product outputs should remain strongly coupled to PersonaKit artifact generation workflows.

## Confidence Score And Threshold

Threshold used: 80 (default)

Pre-research score (low-confidence trigger):

1. Domain understanding: 4/5
2. Delivery planning quality: 3/5
3. Risk and guardrail discipline: 3/5
4. Collaboration and handoff clarity: 4/5
5. Tooling/workflow coverage: 2/5

Total: 16/25 => 64%

Research loop run: Yes (`persona-hiring-research-loop`)

Post-research score:

1. Domain understanding: 4/5
2. Delivery planning quality: 4/5
3. Risk and guardrail discipline: 4/5
4. Collaboration and handoff clarity: 4/5
5. Tooling/workflow coverage: 3/5

Total: 19/25 => 76%

## Verdict

`qualified-with-gaps`

Rationale: Candidate shows strong role intent and good foundational framing, but remains below target threshold due to missing product-management operational artifacts.

## Calibration Matrix (Cycle 1)

| Benchmark Case | Expected Verdict | Actual Verdict | Expected Confidence Range | Actual Confidence | Verdict Match | Confidence Delta |
| --- | --- | --- | --- | --- | --- | --- |
| Mixed-fit PM candidate (`venture-product-steward`) | `qualified-with-gaps` | `qualified-with-gaps` | 70-85 | 76 | Yes | 4 (within 10) |

Drift summary: No verdict mismatch for this case. Confidence delta is within tolerance. Calibration set remains incomplete until strong-fit and weak-fit benchmark cases are added.

## Missing Artifact Recommendations By Type

- Essentials:
  - `venture-product-principles`
  - `feature-brief-template`
  - `roadmap-milestone-tracking-standard`
- Kits:
  - `venture-product-core`
- Intents:
  - `shape-macos-feature-opportunity`
  - `plan-macos-feature-delivery`
- Directives:
  - `run-venture-product-discovery`
  - `run-venture-product-planning`
  - `run-venture-product-tracking`
- Sessions:
  - `venture-product-discovery`
  - `venture-product-planning`
  - `venture-product-tracking`

## First Implementation Step

Create `venture-product-core` kit with one mandatory essential (`feature-brief-template`) and wire a first discovery directive/session so product work can move from idea to structured, reviewable artifact output.
