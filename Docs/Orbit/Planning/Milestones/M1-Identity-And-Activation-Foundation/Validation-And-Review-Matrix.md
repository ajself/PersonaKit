# Validation And Review Matrix

Status: Accepted
Milestone: `M1`
Owner: `studio-coverage-architect`
Primary Execution Persona: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define the deterministic validation and review work required to close `M1`.

## Validation Matrix

| Area | Owner | Evidence type | Pass condition | Disqualifier |
| --- | --- | --- | --- | --- |
| Authored vs runtime boundary | `architectural-editor` | architecture review note | every identity and contract field has clear ownership | runtime policy drift or ambiguous ownership |
| Collaborator identity mapping | `architectural-editor` | model review note | each visible AI collaborator has a stable workspace persona anchor and one authored persona-template mapping | unresolved alias or blended identity |
| Activation record completeness | `studio-coverage-architect` | deterministic tests | required trace fields persist for a successful response | missing directive, trigger, or participant linkage |
| Contract snapshot inspectability | `architectural-editor` | golden example plus review | directive, kits or equivalent, skill posture, stop-point posture, review-gate posture, and memory-scope posture are inspectable | response trace cannot explain why it was allowed |
| Fail-closed ambiguity behavior | `studio-coverage-architect` | deterministic failure tests | ambiguous collaborator or workspace cases block cleanly | silent fallback or unattributed reply |
| Authorization blocking | `studio-coverage-architect` | deterministic failure tests | unauthorized response path is blocked with visible required-versus-authorized skill evidence | response proceeds anyway |
| Activation persistence integrity | `studio-coverage-architect` | failure-path tests | no collaborator response is presented as complete without durable activation state | trace-less output visible as if valid |
| Golden trace correctness | `architectural-editor` and `studio-coverage-architect` | reviewed example plus tests | the documented golden example matches actual behavior | documentation and behavior diverge |
| Operator trace legibility | `architectural-editor` | walkthrough plus snapshots | AJ can explain why a response was allowed or blocked from the UI alone | the trace still requires raw JSON or implementer narration |

## Review Sequence

### Pass 1. Architecture Review

Questions:

- are authored and runtime boundaries explicit and stable?
- does collaborator identity have one trustworthy mapping per visible AI-backed
  participant?
- is the activation contract falsifiable enough to review?

### Pass 2. Coverage Review

Questions:

- are all success and failure paths covered deterministically?
- can ambiguity and authorization failures be reproduced without timing hacks?
- does the golden trace have test support?

### Pass 3. Operator Trust Review

Questions:

- would AJ be able to understand why one response happened?
- would AJ be able to understand why one activation was blocked?
- is the trace difference meaningful enough to justify Orbit's explainability
  claim at this checkpoint?

## Confidence Split

Before `M1` is treated as complete, reviewers should be able to state separate
confidence for:

- contract correctness
- trace inspectability
- failure handling
- deterministic validation coverage

`M1` should not close on a single blended "looks good" judgment.
