# Content Operations Charter

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Mission

Define a decision-complete planning-management system that makes initiative
content generation consistent, deep, and reviewable across passes.

## Objectives

1. Remove ambiguity from planning and pass execution.
2. Enforce deterministic quality gates before final output.
3. Keep planning artifacts auditable and easy to hand off.
4. Reduce drift through explicit daily gardening.

## Guiding Principles

- Clarity over speed.
- Evidence over assumption.
- Determinism over improvisation.
- Human review over autonomous progression.
- Small, reviewable increments over broad rewrites.

## Scope Boundaries

In scope (v1):

- Planning governance for VentureStudio initiative artifacts.
- Pass protocol, rubric, templates, operations policy, and pilot validation.
- Documentation-only implementation.

Out of scope (v1):

- New PersonaKit personas, kits, directives, or sessions.
- Root repository planning governance migration.
- Runtime/API/type changes.

## Roles and Accountability

- Owner (`AJ`): approves gate transitions and scope decisions.
- Reviewer (human-in-the-loop): verifies gate evidence and pass criteria.
- Implementer: authors specs, runs checks, logs remediation.

## Decision Rights

- Gate progression requires owner/reviewer signoff.
- No pass may start if the previous pass exit criteria are unmet.
- Blockers must be resolved before `final` pass.

## Mandatory Governance Rules

1. Every operational planning document must include:
   - `Status`
   - `Owner`
   - `Last Reviewed`
2. Every finding must include:
   - severity
   - owner
   - disposition (`fix now`, `accept`, `defer`)
3. Every gate must define:
   - pass criteria
   - required evidence
   - reviewer signoff requirement

## Deliverables Covered by This Charter

- planning index and gate tracker
- pass protocol
- QA rubric
- template library
- gardening/drift policy
- automation command contracts
- pilot validation plan

## Phase-2 Reserved Encoding Targets

These targets are reserved for post-G5 implementation and are intentionally not
created in v1:

- Persona: `content-gardener`
- Kit: `content-governance-core`
- Directives:
  - `draft-content-pass`
  - `run-editorial-pass`
  - `run-qa-pass`
  - `run-gardening-pass`
- Session: `content-gardening-daily`
