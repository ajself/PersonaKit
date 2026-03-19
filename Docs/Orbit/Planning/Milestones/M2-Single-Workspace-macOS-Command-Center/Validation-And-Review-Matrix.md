# M2 Validation And Review Matrix

Status: Accepted
Milestone: `M2`
Owner: `studio-coverage-architect`
Primary Execution Persona: `senior-swiftui-engineer`
Last Updated: 2026-03-18

## Purpose

Define the deterministic validation and review work required to close `M2`
honestly.

## Validation Matrix

| Area | Owner | Evidence type | Pass condition | Disqualifier |
| --- | --- | --- | --- | --- |
| Workspace and roster first-open clarity | `venture-product-steward` | product acceptance review | the room communicates workspace, roster, and active discussion on first scan | room identity remains weak or confusing |
| Empty and seeded state coherence | `venture-product-steward` and `studio-interaction-quality-lead` | walkthrough review and acceptance notes | first-open states support the same believable room model without fake urgency | seeded or empty state feels theatrical, confusing, or structurally inconsistent |
| Interaction quality and visual stability | `studio-interaction-quality-lead` | interaction review artifact | panel composition is stable, top-aligned, and understandable without help | layout drift, false default emphasis, or interaction ambiguity |
| Snapshot-based visual proof | `studio-coverage-architect` and `studio-interaction-quality-lead` | snapshot tests and review notes | first-open room, seeded or empty states, and trace affordances are captured in stable snapshots that support regression review and help reviewers inspect accessibility-sensitive changes | visual regressions or accessibility-impacting shifts are hard to see or defend |
| Local persistence integrity | `studio-coverage-architect` | deterministic tests and restart verification | runtime state round-trips and survives restart cleanly | lost thread state, unstable persistence, or partial reload |
| Speaker attribution | `studio-coverage-architect` | deterministic tests and review notes | user and participant responses stay visibly attributable | attribution is partial, ambiguous, or degraded after reload |
| Direct addressing and lightweight multi-participant behavior | `venture-product-steward` and `studio-coverage-architect` | walkthrough review and validation notes | the interaction path is understandable and attributable | opaque routing or accidental-feeling responses |
| Activation trace visibility | `studio-interaction-quality-lead` and `studio-coverage-architect` | review artifact and trace walkthrough | trace is discoverable, useful, and lightweight | trace is hidden, heavy, or product-useless |
| Orbit-specific product bar | `venture-product-steward` and `studio-interaction-quality-lead` | acceptance result plus review notes | the room feels structurally different from generic chat | commodity-chat feel remains the dominant impression |
| Rerun evidence completeness | `samwise` | closeout packet audit | all required attempt artifacts exist and are coherent | milestone is called ready without a full evidence packet |
| Red-pen discipline | `samwise` | red-pen evidence audit | each active owner completed the required red-pen passes | quality claims rely on unreviewed first drafts |

## Review Sequence

### Pass 1. Product Review

Questions:

- does the room read as Orbit before any deep explanation?
- do workspace, roster, thread, and trace reinforce the same product model?

### Pass 2. Interaction Review

Questions:

- is the surface visually stable and comprehensible on first open?
- does the trace affordance support trust without visual overload?

### Pass 3. Validation Review

Questions:

- do persistence, attribution, and restart behaviors hold deterministically?
- is there evidence for both direct and lightweight multi-participant behavior?
- does the trace stay product-visible rather than debug-only?

### Pass 4. Closeout Review

Questions:

- do the artifacts justify the product confidence being claimed?
- is the comparison-grade rerun standard actually met?

## Confidence Split

Before `M2` is treated as complete, reviewers should be able to state separate
confidence for:

- feature behavior
- product quality
- process quality
- persona-fidelity quality

`M2` should not close on a single blended `looks good` judgment.
