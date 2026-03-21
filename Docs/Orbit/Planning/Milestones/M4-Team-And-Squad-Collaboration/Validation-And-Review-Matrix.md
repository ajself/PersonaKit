# M4 Validation And Review Matrix

Status: Ready For Planning Closeout
Milestone: `M4`
Owner: `studio-coverage-architect`
Primary Execution Persona: `orbit-meeting-coordinator`
Last Updated: 2026-03-20

## Purpose

Define the deterministic validation and review work required to close `M4`
honestly.

## Validation Matrix

| Area | Owner | Evidence type | Pass condition | Disqualifier |
| --- | --- | --- | --- | --- |
| Group structure semantics | `samwise` and `venture-product-steward` | Packet 1 review plus decision-register check | teams, squads, and their first-pass inspection surface are explicit and bounded | group structure still depends on ad hoc roster interpretation |
| Target expansion determinism | `studio-coverage-architect` | expansion examples and validation notes | the same target produces the same participant set and reason model under the same workspace state | expansion stays opaque or inconsistent |
| Inclusion and exclusion reasoning clarity | `venture-product-steward` and `studio-interaction-quality-lead` | product and trust review artifact | the operator can tell why each participant was included or excluded | reasoning exists only in implementer explanation or hidden logs |
| Inline reply legibility | `venture-product-steward` and `studio-interaction-quality-lead` | interaction walkthrough and Packet 3 review | group replies remain attributable and understandable inside the existing thread model | the exchange feels like a confusing broadcast or accidental meeting |
| Participation roles and completion state clarity | `studio-interaction-quality-lead` and `studio-coverage-architect` | state walkthrough and Packet 4 review | roles, active/done state, and partial-failure behavior are visible and coherent | state stays hand-wavy or aggregate success hides per-participant reality |
| Orbit-owned coordination boundary | `samwise` and `venture-product-steward` | boundary review note | `M4` stays inline collaboration work and does not smuggle in `M5` or `M7` semantics | packet docs or runtime behavior blur milestone boundaries |
| Persona-fidelity discipline | `samwise` | owner-fit audit with `PHR-0009` | `orbit-meeting-coordinator` remains the explicit owner and no substitute-owner language returns | milestone owner becomes generic or implied again |
| Evidence completeness | `samwise` | dossier audit | README, quality bar, decision register, packet docs, and validation matrix agree on packet order, scope, and stop points | the milestone is called ready from the README alone |

## Review Sequence

### Pass 1. Scope And Owner Review

Questions:

- is `orbit-meeting-coordinator` still the explicit owner everywhere it matters?
- do the packet docs keep `M4` bounded to inline collaboration and visible
  coordinator expansion?

### Pass 2. Product And Interaction Review

Questions:

- will group targeting and inline replies feel understandable without a deep
  explanation?
- does the operator-facing reasoning feel trustworthy rather than magical?

### Pass 3. Validation Review

Questions:

- are expansion examples, exclusion examples, and state examples strong enough
  to defend the packet claims?
- does the packet set make nondeterminism or hidden failure hard to hide?

### Pass 4. AJ Closeout Review

Questions:

- is the dossier strong enough to authorize a runtime-facing packet without
  improvising the milestone contract?
- are the stop points explicit enough that later execution will know when to
  pause instead of broadening scope?

## Confidence Split

Before `M4` is treated as ready for runtime-facing work, reviewers should be
able to state separate confidence for:

- feature semantics
- product trust and interaction quality
- validation and evidence quality
- persona-fidelity and stop-point discipline

`M4` should not advance on a single blended `group replies looked fine` judgment.
