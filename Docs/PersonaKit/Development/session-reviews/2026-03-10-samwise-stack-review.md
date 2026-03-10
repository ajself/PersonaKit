# Session Stack Review

- Date: 2026-03-10
- Objective: Review the Samwise persona, Samwise-associated kits, and all Samwise sessions through the `samwise-session-stack-review` workflow to judge whether context is scaling through kits and sessions cleanly.
- Target Session Ref: `samwise-session-stack-review`
- Normalized Session ID: `samwise-session-stack-review`
- Verdict: `caution`
- MCP Status: `pass`

## Scope Inventory

- Persona:
  - `samwise`
- Reviewed kits:
  - `trusted-partner-core`
  - `persona-hiring-core`
  - `samwise-orchestration-core`
  - `orbit-build-rerun-core`
- Reviewed sessions:
  - `samwise-coffee-checkpoint`
  - `samwise-daily-closeout`
  - `samwise-partner-sync`
  - `samwise-session-stack-review`
  - `samwise-orbit-build-rerun`
  - `samwise-orbit-rerun-execution`
  - `samwise-persona-hiring`
  - `samwise-persona-hiring-calibration`
  - `samwise-squad-planning`
  - `samwise-squad-planning-remediation`
  - `samwise-worktree-squad-oversight`

## Findings

1. [P1] `samwise-orchestration-core` is still doing too many jobs at once, so sessions that only need execution oversight or Orbit execution inherit planning, hiring, and retrospective machinery that is unrelated to their immediate job. The mix is visible directly in [.personakit/Packs/kits/samwise-orchestration-core.kit.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/kits/samwise-orchestration-core.kit.json#L5), and that broad kit is now explicitly loaded by [samwise-orbit-rerun-execution.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-orbit-rerun-execution.session.json#L1), [samwise-squad-planning.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-squad-planning.session.json#L1), [samwise-squad-planning-remediation.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-squad-planning-remediation.session.json#L1), and [samwise-worktree-squad-oversight.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-worktree-squad-oversight.session.json#L1). The persona slimming worked, but the orchestration kit is still a multiplexed bundle.

2. [P2] `samwise-coffee-checkpoint` is still heavier than its “friendly neutral startup” promise because the intent directly includes planning contracts. The boundary drift now lives in [.personakit/Packs/intents/samwise-coffee-checkpoint.intent.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/intents/samwise-coffee-checkpoint.intent.json#L33), where `multiagent-squad-planning-contract` and `squad-planning-log-contract` are loaded into a wake-up flow that is supposed to stay concise and orientation-first. The base persona is lean, but this session still overreaches.

3. [P2] The operator-facing lifecycle states understate several Samwise specialist lanes as `candidate` even though continuity logs describe them as real, validated flows. See [session-directory.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/session-directory.md#L55), [session-directory.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/session-directory.md#L56), [session-directory.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/session-directory.md#L58), and [session-directory.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/session-directory.md#L59) versus the continuity trail in [pack-gardener-log.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/pack-gardener-log.md#L44), [pack-gardener-log.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/pack-gardener-log.md#L45), and [partner-context-log.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/partner-context-log.md#L90). The graph is fine, but the session directory can still surprise an operator.

4. [P3] `trusted-partner-core` is the right default base after the persona slimming pass, but it still brings `samwise-daily-closeout` into every Samwise session whether or not closeout is central to the session’s job. That default is probably acceptable, but it is the remaining prompt-mass cost of the otherwise clean base kit in [.personakit/Packs/kits/trusted-partner-core.kit.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/kits/trusted-partner-core.kit.json#L5).

## Artifact Table

| Artifact | Type | S | W | O | T | Current | Projected | Highest-Risk Note | Smallest Red-Pen Fix |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `samwise` | persona | Clear identity anchor | Many operational guardrails now live outside the persona | Keep the persona stable and lean | Reviewers may read the persona alone and miss session-scoped behavior | 8.6 | 8.9 | Kit-scoped constraints can be under-read | Add one short operator note that Samwise behavior is now kit/session-scoped by design |
| `trusted-partner-core` | kit | Coherent default base | Closeout protocol rides into every Samwise session | Keep as the only default kit | Mild prompt mass for narrow sessions | 8.7 | 9.0 | Every Samwise session inherits closeout context | Decide whether closeout remains a universal Samwise default or becomes an explicit opt-in for narrow sessions |
| `persona-hiring-core` | kit | Tight hiring-specific scope | Repeats shared trust/non-goals/tool constraints | Leave it focused and dedupe later if useful | Can hide orchestration problems by compensating for them | 8.8 | 9.0 | Shared essentials are repeated rather than composed | Dedupe repeated shared essentials once orchestration-kit boundaries are settled |
| `samwise-orchestration-core` | kit | Captures real Samwise delivery patterns | Mixes planning, hiring, oversight, and retrospective concerns | Split by workflow family | One kit still stands in for several jobs | 6.4 | 8.6 | Sessions inherit unrelated context through one broad override | Split this kit into planning, oversight, and retrospective-oriented kits |
| `orbit-build-rerun-core` | kit | Orbit-specific and focused | Depends on broader orchestration choices for final precision | Keep it narrow and Orbit-only | Generic Samwise problems can be misattributed to Orbit | 8.9 | 9.1 | Execution softness can be blamed on the wrong kit | Repoint Orbit execution sessions to narrower orchestration successors once they exist |
| `samwise-coffee-checkpoint` | session | Clear wake-up ritual and resume-context behavior | Intent still pulls planning contracts | Split a lighter wake-up path from planning-aware resume mode | Simple startup feels heavier than promised | 6.9 | 8.1 | Planning contracts in the coffee intent | Remove direct planning-contract loading from the coffee intent unless the flow is explicitly planning-aware |
| `samwise-daily-closeout` | session | Focused and coherent | Also arrives by default through the base kit | Keep the workflow stable | Default inclusion may be unnecessary for some sessions | 8.8 | 8.9 | Closeout context is always present | Keep the session as-is and revisit only if base-kit slimming makes it redundant |
| `samwise-partner-sync` | session | Lean and aligned with partner role | Inherits closeout despite not being a closeout flow | Keep as canonical partner front door | Slightly broader than necessary | 8.6 | 8.8 | Inherited closeout weight | Re-evaluate inherited closeout once the base-kit boundary is finalized |
| `samwise-session-stack-review` | session | Strong narrow canary for the slimmer Samwise shape | Still carries base-kit closeout context | Use as reference for future narrow sessions | Review exports still include some non-review partner context | 9.0 | 9.1 | Inherited closeout context | Keep this session stable and use it as the canary when narrowing shared kits |
| `samwise-orbit-build-rerun` | session | Lean startup-only Orbit surface | Depends on execution session for full artifact coverage | Keep as staging-only | Startup users can still overread its authority | 8.2 | 8.9 | Strong handoff dependence | Keep the startup boundary explicit in docs and avoid adding execution concerns back into this session |
| `samwise-orbit-rerun-execution` | session | Explicit execution lane with real review surfaces | Override still pulls broad orchestration kit | Replace broad override with narrower execution/oversight kit(s) | Execution lane still carries planning and hiring ballast | 7.1 | 8.5 | Orchestration override is too broad | Swap the broad orchestration override for execution- and oversight-specific kits after decomposition |
| `samwise-persona-hiring` | session | Explicit and lean after persona slimming | Lifecycle label still says `candidate` | Promote lifecycle or explain why it stays candidate | Operator may undertrust a mature lane | 8.4 | 8.7 | Lifecycle classification mismatch | Align the session-directory lifecycle label with the continuity trail or explain the exception |
| `samwise-persona-hiring-calibration` | session | Explicit hiring-only override | Session name suggests calibration while directive is remediation-focused | Clarify naming or session-directory description | Operator surprise about exact purpose | 8.0 | 8.5 | Naming and behavior are not perfectly aligned | Tighten the operator description or rename the session so calibration and remediation meaning match |
| `samwise-squad-planning` | session | Explicit opt-in breadth | Still uses the same broad orchestration kit as other families | Move to a planning-specific kit | Planning remains larger than it needs to be | 7.5 | 8.6 | Orchestration kit does too much | Rewire this session to a planning-specific orchestration successor |
| `samwise-squad-planning-remediation` | session | Explicit role-gap closure path | Candidate state plus broad kit mix feels provisional | Clarify lifecycle and narrow the kit | Remediation lane can feel half-promoted | 7.2 | 8.4 | Candidate state plus broad orchestration mix | Narrow the kit and then reconcile the lifecycle label with actual usage |
| `samwise-worktree-squad-oversight` | session | Explicit opt-in oversight lane | Oversight still loads planning and hiring ballast | Replace broad override with an oversight-specific kit | Oversight session carries unrelated context | 7.2 | 8.5 | Orchestration override is too broad | Rewire oversight to an oversight-specific orchestration successor |

## Per-Artifact SWOT Notes

- `samwise`: Strength: clean identity anchor. Weakness: some operational guardrails are only visible through kits/sessions. Opportunity: keep the persona stable and lean. Threat: reviewers may under-read kit-scoped behavior by stopping at the persona file.
- `trusted-partner-core`: Strength: coherent default base. Weakness: closeout context rides into every Samwise session. Opportunity: keep it as the stable base kit. Threat: narrow sessions pay a small prompt-mass tax.
- `persona-hiring-core`: Strength: clearly hiring-specific. Weakness: repeats shared trust/non-goals/tool essentials. Opportunity: keep hiring boundaries explicit. Threat: orchestration problems can be masked if hiring keeps compensating for them.
- `samwise-orchestration-core`: Strength: captures real Samwise delivery patterns. Weakness: planning, hiring, oversight, and retrospective concerns are bundled together. Opportunity: split by workflow family. Threat: any session that loads orchestration inherits unrelated context.
- `orbit-build-rerun-core`: Strength: Orbit-specific and focused. Weakness: final execution precision still depends on broader kit boundaries. Opportunity: keep Orbit logic isolated. Threat: generic Samwise execution issues can be misattributed to Orbit.
- `samwise-coffee-checkpoint`: Strength: warm wake-up ritual with clear resume-context behavior. Weakness: intent still pulls planning contracts. Opportunity: make the wake-up surface lighter. Threat: startup can feel heavier than the user-facing promise.
- `samwise-daily-closeout`: Strength: focused and coherent. Weakness: also arrives by default through the base kit. Opportunity: keep the workflow stable. Threat: non-closeout sessions always inherit closeout context.
- `samwise-partner-sync`: Strength: lean and aligned with the partner role. Weakness: inherits closeout context it does not strictly need. Opportunity: keep it as the canonical partner front door. Threat: slightly broader prompt mass than necessary.
- `samwise-session-stack-review`: Strength: strong narrow canary for the slimmer Samwise shape. Weakness: still carries base-kit closeout context. Opportunity: use it as the model for future narrow sessions. Threat: exports still include some non-review partner context.
- `samwise-orbit-build-rerun`: Strength: lean startup-only Orbit surface. Weakness: depends on execution-session follow-through for full artifact coverage. Opportunity: keep it staging-only. Threat: startup users can still overread its authority.
- `samwise-orbit-rerun-execution`: Strength: explicit execution lane with real review surfaces. Weakness: orchestration override is still too broad. Opportunity: move to narrower execution/oversight kits. Threat: execution lane still carries planning and hiring ballast.
- `samwise-persona-hiring`: Strength: explicit and lean after persona slimming. Weakness: lifecycle label still says `candidate`. Opportunity: promote lifecycle or explain the state better. Threat: operators may undertrust a mature lane.
- `samwise-persona-hiring-calibration`: Strength: explicit hiring-only override. Weakness: session name suggests calibration while the directive is remediation-focused. Opportunity: tighten naming or operator docs. Threat: operator surprise about what the lane really does.
- `samwise-squad-planning`: Strength: explicit opt-in breadth. Weakness: still uses the same broad orchestration kit as other families. Opportunity: move to a planning-specific kit. Threat: planning remains larger than necessary.
- `samwise-squad-planning-remediation`: Strength: explicit role-gap closure path. Weakness: candidate state plus broad kit mix feels provisional. Opportunity: clarify lifecycle and narrow the kit. Threat: remediation lane can feel half-promoted.
- `samwise-worktree-squad-oversight`: Strength: explicit opt-in oversight lane. Weakness: oversight still loads planning and hiring ballast. Opportunity: move to an oversight-specific kit. Threat: oversight sessions carry unrelated context.

## Family-by-Family SWOT Summary

### Persona And Base Kit

- Strengths: Samwise now reads like a stable identity layer, and `trusted-partner-core` is a coherent default base.
- Weaknesses: The base still carries closeout context into every session.
- Opportunities: Keep this layer stable and do future refinement below it.
- Threats: Reviewers may judge Samwise from the persona alone and miss session-scoped constraints.

### Shared Kits

- Strengths: `persona-hiring-core` and `orbit-build-rerun-core` are comparatively well-bounded.
- Weaknesses: `samwise-orchestration-core` mixes four families of concerns.
- Opportunities: Split orchestration into planning, oversight, and retrospective-oriented kits.
- Threats: Any session that asks for orchestration still inherits too much by side effect.

### Identity/Core Sessions

- Strengths: `samwise-daily-closeout`, `samwise-partner-sync`, and `samwise-session-stack-review` are clean, and `samwise-orbit-build-rerun` is much better than before.
- Weaknesses: `samwise-coffee-checkpoint` still loads planning-specific context.
- Opportunities: Make coffee mode an even cleaner wake-up surface.
- Threats: Startup behavior can still feel heavier than the user-facing ritual implies.

### Hiring And Planning Sessions

- Strengths: The persona-slimming pass made these flows explicit and deterministic through `kitOverrides`.
- Weaknesses: Lifecycle states and naming still create some operator ambiguity.
- Opportunities: Promote mature lanes and clarify the calibration/remediation naming split.
- Threats: An operator can misread `candidate` as “not ready” even when the continuity trail says otherwise.

### Execution Sessions

- Strengths: Orbit startup and execution are now separate, and worktree oversight remains explicit.
- Weaknesses: Execution and oversight lanes still rely on the overly broad orchestration kit.
- Opportunities: Execution is the clearest place to prove narrower kit decomposition.
- Threats: Planning and hiring ballast can re-enter the prompt surface through these overrides.

## Current Confidence Summary

- Persona: `8.6`
- Base/default kit layer: `8.7`
- Shared kit layer: `8.0`
- Identity/core session family: `8.3`
- Hiring/planning session family: `7.8`
- Execution session family: `7.5`
- Current overall confidence: `7.8`
- Current verdict: `caution`

## Red-Pen Recommendations

### Persona

- Keep [samwise.persona.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/personas/samwise.persona.json) stable for now.
- Do not push more operational detail back into the persona file unless a rule truly belongs to identity rather than kit/session scope.

### Kit Boundaries

- Split [samwise-orchestration-core.kit.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/kits/samwise-orchestration-core.kit.json#L1) into smaller workflow-aligned kits.
- Minimum recommended split:
  - planning core
  - worktree oversight core
  - retrospective core
- Keep `persona-hiring-core` separate instead of embedding hiring essentials in orchestration.

### Session Wiring

- Remove planning contracts from [samwise-coffee-checkpoint.intent.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/intents/samwise-coffee-checkpoint.intent.json#L33) unless the coffee flow is explicitly the planning-aware `resume-context` path.
- Revisit [samwise-orbit-rerun-execution.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-orbit-rerun-execution.session.json#L1) and [samwise-worktree-squad-oversight.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-worktree-squad-oversight.session.json#L1) once narrower orchestration kits exist.
- Clarify whether [samwise-persona-hiring-calibration.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-persona-hiring-calibration.session.json#L1) should stay a remediation lane, be renamed, or have its operator description tightened.

### Docs And Continuity

- Align [session-directory.md](/Users/ajself/Code/PersonaKit/Docs/PersonaKit/Development/session-directory.md#L51) with the real intended lifecycle of Samwise specialist lanes.
- Add one short note in the session directory or Samwise docs that Samwise now scales by `trusted-partner-core` by default and explicit session `kitOverrides` for broader responsibilities.

## Projected Confidence After Red-Pen

- Persona: `8.9`
- Base/default kit layer: `9.0`
- Shared kit layer: `8.8`
- Identity/core session family: `8.7`
- Hiring/planning session family: `8.5`
- Execution session family: `8.6`
- Projected overall confidence: `8.8`
- Projected verdict: `safe`

This pass shows that the Samwise persona slimming was the right move. The main remaining risk is no longer “Samwise is too broad by default,” but “one shared orchestration kit still re-broadens several explicit execution and planning sessions.” The next high-leverage work is kit-boundary decomposition, followed by small doc/lifecycle cleanup so the operator-facing story matches the live PersonaKit graph.
