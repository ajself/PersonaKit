# Session Stack Review

- Date: 2026-03-10
- Objective: Review the full Samwise-related pack graph through the `samwise-session-stack-review` workflow to judge whether Samwise pack context is scaling cleanly through kits, directives, intents, essentials, and skills.
- Target Session Ref: `samwise-session-stack-review`
- Normalized Session ID: `samwise-session-stack-review`
- Verdict: `caution`
- MCP Status: `pass`

## Scope Inventory

The live graph was discovered MCP-first from Samwise session traces. This review scores the material shared and Orbit-specific pack surfaces that most shape Samwise behavior.

- Reviewed kits:
  - `orbit-build-rerun-core`
  - `persona-hiring-core`
  - `samwise-orchestration-core`
  - `trusted-partner-core`
- Reviewed directives:
  - `assemble-squad-and-plan`
  - `oversee-worktree-squad-delivery`
  - `run-orbit-build-rerun`
  - `run-orbit-rerun-squad-execution`
  - `run-samwise-coffee-checkpoint`
  - `run-session-stack-red-pen-review`
- Reviewed intents:
  - `assemble-squad-and-plan-review`
  - `gated-worktree-delivery`
  - `orbit-rerun-squad-execution`
  - `reverse-interview-persona-fit`
  - `samwise-coffee-checkpoint`
  - `session-stack-review`
- Reviewed essentials:
  - `multiagent-squad-planning-contract`
  - `orbit-attempt-improvement-loop`
  - `orbit-build-rerun-playbook`
  - `partner-trust-contract`
  - `persona-hiring-log-contract`
  - `persona-hiring-standards`
  - `samwise-daily-closeout`
  - `squad-planning-log-contract`
  - `tools-and-constraints`
  - `worktree-squad-gating-contract`
  - `worktree-squad-loop-log-contract`
  - `worktree-squad-retrospective-template`
- Reviewed skills:
  - `codex-cli`

## Findings

1. [P1] `samwise-orchestration-core` is still the dominant scope-bleed source in the Samwise pack graph because it bundles planning, hiring, worktree gating, logging, calibration, and retrospective contracts into one shared override. The breadth is explicit in [.personakit/Packs/kits/samwise-orchestration-core.kit.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/kits/samwise-orchestration-core.kit.json#L5), and it directly duplicates the hiring standards already isolated in [.personakit/Packs/kits/persona-hiring-core.kit.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/kits/persona-hiring-core.kit.json#L5). As a result, planning, oversight, and Orbit execution sessions inherit unrelated contracts by side effect.

2. [P1] The worktree execution layer is effective but not cohesive because authority is split across the orchestration kit, the Samwise oversight directive, the worktree delivery intent, and the worktree gating essential. Compare the responsibilities in [oversee-worktree-squad-delivery.directive.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/directives/oversee-worktree-squad-delivery.directive.json#L5), [gated-worktree-delivery.intent.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/intents/gated-worktree-delivery.intent.json#L38), and [worktree-squad-gating-contract.md](/Users/ajself/Code/PersonaKit/.personakit/Packs/essentials/worktree-squad-gating-contract.md#L19). The result is duplicated gate logic and a fuzzier-than-ideal boundary between Samwise oversight, Worktree Squad delivery, and retrospective obligations.

3. [P2] The Orbit execution pack layer still under-enforces explicit routing because [orbit-rerun-squad-execution.intent.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/intents/orbit-rerun-squad-execution.intent.json#L68) leaves implementation and review session ids optional, even though [run-orbit-rerun-squad-execution.directive.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/directives/run-orbit-rerun-squad-execution.directive.json#L14) requires Samwise to declare the active session map before coding begins. The Orbit playbook itself is disciplined; the enforcement gap lives in the intent schema.

4. [P2] The coffee/startup pack layer is still heavier than its stated job because [samwise-coffee-checkpoint.intent.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/intents/samwise-coffee-checkpoint.intent.json#L33) directly loads `multiagent-squad-planning-contract`, `squad-planning-log-contract`, and `samwise-daily-closeout` into a wake-up flow that is supposed to stay concise and orientation-first. This makes the lightest Samwise ritual carry planning and closeout ballast before the user has even chosen a deep-execution path.

5. [P3] `trusted-partner-core` is the right default base, but it still hard-wires closeout into every Samwise pack graph through [trusted-partner-core.kit.json](/Users/ajself/Code/PersonaKit/.personakit/Packs/kits/trusted-partner-core.kit.json#L6) and the closeout obligations in [partner-trust-contract.md](/Users/ajself/Code/PersonaKit/.personakit/Packs/essentials/partner-trust-contract.md#L32). That is not a blocker, but it means even narrow review or startup surfaces inherit continuity-closeout context whether they need it or not.

## Artifact Table

| Artifact | Type | Current | Projected | Highest-Risk Note | Smallest Red-Pen Fix |
| --- | --- | --- | --- | --- | --- |
| `trusted-partner-core` | kit | 8.6 | 8.9 | Default Samwise surfaces always inherit closeout context | Decide whether closeout remains universal or becomes an explicit opt-in for narrow sessions |
| `persona-hiring-core` | kit | 8.3 | 8.8 | Hiring standards are duplicated again through orchestration | Keep hiring isolated and remove hiring contracts from broader orchestration kits |
| `samwise-orchestration-core` | kit | 6.2 | 8.5 | One shared override still stands in for planning, oversight, hiring, and retrospective work | Split this kit into planning, oversight, and retrospective-oriented successors |
| `orbit-build-rerun-core` | kit | 8.9 | 9.1 | Orbit can be blamed for generic orchestration problems upstream | Keep Orbit-specific context isolated and rewire it to narrower shared kits later |
| `run-samwise-coffee-checkpoint` | directive | 7.1 | 8.2 | Startup directive depends on a heavier-than-promised intent surface | Keep the directive light and slim the coffee intent underneath it |
| `assemble-squad-and-plan` | directive | 7.7 | 8.7 | Planning directive still inherits broader-than-needed orchestration context | Re-anchor the directive to a planning-specific kit boundary |
| `oversee-worktree-squad-delivery` | directive | 7.2 | 8.4 | Oversight responsibilities overlap with delivery and gating packs | Separate oversight authority from delivery and retrospective authority |
| `run-orbit-build-rerun` | directive | 8.4 | 8.9 | Startup can still be overread as execution authority | Keep startup-only boundary explicit and resist adding execution concerns |
| `run-orbit-rerun-squad-execution` | directive | 7.6 | 8.6 | Directive expects a stricter session map than the intent schema enforces | Make the intent require the session map the directive already assumes |
| `run-session-stack-red-pen-review` | directive | 9.0 | 9.2 | Review contract is only as good as the persistence discipline around it | Keep it stable and use it as the canary for future pack reviews |
| `samwise-coffee-checkpoint` | intent | 6.8 | 8.1 | Planning and closeout contracts are loaded into the wake-up flow | Remove direct planning-contract loading unless the flow is explicitly planning-aware |
| `assemble-squad-and-plan-review` | intent | 7.8 | 8.8 | Planning review repeats work already packed into orchestration | Narrow orchestration and let the intent own only planning-specific requirements |
| `reverse-interview-persona-fit` | intent | 8.4 | 8.9 | Hiring logic can be duplicated across multiple pack layers | Keep this as the single canonical hiring-fit surface |
| `gated-worktree-delivery` | intent | 7.4 | 8.5 | Delivery intent mixes delivery gates, product quality, and retrospective prerequisites | Move retrospective concerns out unless they are strictly required for delivery entry |
| `orbit-rerun-squad-execution` | intent | 7.1 | 8.6 | Implementation and review session routes are optional even though the contract wants them explicit | Require the specialist session ids or encode deterministic defaults |
| `session-stack-review` | intent | 9.1 | 9.2 | Review flow depends on continued MCP health and report discipline | Keep it stable and use it for future pack/gap reviews |
| `partner-trust-contract` | essential | 8.5 | 8.8 | Trust and closeout obligations are coupled for every Samwise surface | Split universal trust rules from optional closeout behavior if prompt mass remains an issue |
| `samwise-daily-closeout` | essential | 8.4 | 8.6 | Closeout is globally inherited through the base kit | Keep the contract stable and revisit only if base-kit slimming demands it |
| `multiagent-squad-planning-contract` | essential | 7.6 | 8.6 | Planning contract is leaking into non-planning experiences like coffee mode | Restrict this contract to planning and execution surfaces only |
| `persona-hiring-standards` | essential | 8.5 | 8.9 | Hiring standards are clear but duplicated through multiple kits | Make this essential flow through the hiring kit only |
| `persona-hiring-log-contract` | essential | 8.8 | 9.0 | Durable hiring logging is solid but repeated in broader packs | Keep the contract and reduce duplication around it |
| `squad-planning-log-contract` | essential | 7.9 | 8.6 | Planning log contract is being dragged into startup and execution surfaces indirectly | Load it only where planning output is actually required |
| `worktree-squad-gating-contract` | essential | 7.5 | 8.5 | Gate and authority rules are duplicated across directive, intent, and essential layers | Make this the canonical gate authority and trim overlapping prose elsewhere |
| `worktree-squad-loop-log-contract` | essential | 7.9 | 8.6 | Loop logging is useful but pulled into more contexts than necessary | Keep it tied to actual worktree loops and retrospective ownership |
| `worktree-squad-retrospective-template` | essential | 7.7 | 8.4 | Retrospective machinery appears too early in some execution surfaces | Reserve it for retrospective ownership and late-gate evidence needs |
| `orbit-build-rerun-playbook` | essential | 8.9 | 9.1 | Orbit startup/execution discipline can be weakened by shared-pack softness upstream | Keep this essential narrow and let shared-kit cleanup happen around it |
| `orbit-attempt-improvement-loop` | essential | 8.9 | 9.1 | Orbit learning rules are solid but depend on broader evidence discipline | Keep it stable and pair it with stricter execution-session enforcement |
| `tools-and-constraints` | essential | 8.6 | 8.8 | Universal constraints are repeated across many pack layers | Keep as a shared base essential and reduce repeated pack-level restatement |
| `codex-cli` | skill | 9.2 | 9.2 | The skill is stable; the risk is how broadly packs route through it | No change needed here |

## Per-Pack SWOT Notes

### Kits

- `trusted-partner-core`: Strength: coherent default trust base. Weakness: globally inherits closeout. Opportunity: keep it as the stable base layer. Threat: narrow Samwise surfaces pay a context tax.
- `persona-hiring-core`: Strength: hiring responsibilities are clearly isolated. Weakness: some of its standards are repeated through orchestration. Opportunity: make it the single hiring boundary. Threat: hiring can mask orchestration-design problems.
- `samwise-orchestration-core`: Strength: captures real delivery concerns Samwise must handle. Weakness: it mixes too many workflow families. Opportunity: decompose into smaller workflow-aligned kits. Threat: any session that opts in inherits unrelated context.
- `orbit-build-rerun-core`: Strength: tight Orbit-specific scope. Weakness: it depends on cleaner shared-pack boundaries for full precision. Opportunity: keep Orbit logic isolated. Threat: generic Samwise issues can be misattributed to Orbit.

### Directives

- `run-samwise-coffee-checkpoint`: Strength: clear startup ritual. Weakness: relies on an overpacked wake-up intent. Opportunity: keep the directive minimal. Threat: users experience startup as heavier than promised.
- `assemble-squad-and-plan`: Strength: clean planning stop-before-execution contract. Weakness: inherited orchestration context is broader than planning alone needs. Opportunity: pair it with a planning-only shared kit. Threat: planning can absorb hiring and retrospective ballast by default.
- `oversee-worktree-squad-delivery`: Strength: explicit Samwise oversight role. Weakness: authority overlaps with delivery and gate packs. Opportunity: make oversight the human-facing controller and trim duplicate gate prose elsewhere. Threat: boundary ambiguity between Samwise and Worktree Squad Lead.
- `run-orbit-build-rerun`: Strength: startup/execution split is clear. Weakness: it still depends on stronger downstream enforcement to stay honest. Opportunity: preserve this as the clean Orbit staging surface. Threat: startup can again drift toward pseudo-execution.
- `run-orbit-rerun-squad-execution`: Strength: clearly anti-solo and review-heavy. Weakness: the directive is stricter than the intent schema beneath it. Opportunity: harden the intent to match the directive. Threat: routing gaps remain possible under pressure.
- `run-session-stack-red-pen-review`: Strength: best-enforced MCP-first review contract in the repo. Weakness: persistence quality still matters. Opportunity: reuse it for more pack-level reviews. Threat: weak artifacts can still under-deliver a strong directive.

### Intents

- `samwise-coffee-checkpoint`: Strength: concise wake-up goal. Weakness: planning and closeout essentials are loaded too early. Opportunity: split light wake-up from planning-aware resume mode. Threat: every wake-up carries latent planning ballast.
- `assemble-squad-and-plan-review`: Strength: planning requirements are explicit. Weakness: it overlaps with orchestration-level planning essentials. Opportunity: let the intent own planning while the kit boundary narrows. Threat: duplicated planning context inflates prompt mass.
- `reverse-interview-persona-fit`: Strength: canonical hiring-fit surface. Weakness: it is easy to duplicate through broader kits. Opportunity: keep this as the one hiring gate. Threat: hiring logic becomes ambient rather than explicit.
- `gated-worktree-delivery`: Strength: bounded delivery and evidence expectations are clear. Weakness: it drags in more surrounding process context than a pure delivery lane needs. Opportunity: separate delivery entry from retrospective ownership. Threat: delivery becomes a catch-all process surface.
- `orbit-rerun-squad-execution`: Strength: attempt-specific artifact routing is explicit. Weakness: specialist session ids remain optional. Opportunity: make the session map mandatory. Threat: the multiagent claim can still be under-enforced.
- `session-stack-review`: Strength: compact and MCP-first. Weakness: it depends on disciplined artifact persistence. Opportunity: use it as a stable pack-review chassis. Threat: weak review artifacts can undercut a strong review contract.

### Essentials

- `partner-trust-contract`: Strength: trust and review rules are clear. Weakness: closeout comes bundled with universal trust. Opportunity: split universal vs optional behavior if needed. Threat: every Samwise surface inherits continuity weight.
- `samwise-daily-closeout`: Strength: strong continuity discipline. Weakness: it appears in more places than closeout-specific work requires. Opportunity: keep the contract stable and narrow its loading later. Threat: it becomes ambient rather than intentional.
- `multiagent-squad-planning-contract`: Strength: excellent planning boundary. Weakness: it leaks into startup surfaces that are not doing planning yet. Opportunity: confine it to planning/execution lanes. Threat: wake-up and staging surfaces over-prepare.
- `persona-hiring-standards`: Strength: hiring rubric is well-scoped. Weakness: repeated loading across kits. Opportunity: make it flow from the hiring kit only. Threat: hiring context becomes ambient.
- `persona-hiring-log-contract`: Strength: durable and deterministic. Weakness: it appears indirectly in non-hiring pack stacks. Opportunity: keep it canonical and reduce incidental loading. Threat: low-value duplication persists.
- `squad-planning-log-contract`: Strength: planning output discipline is clear. Weakness: it appears outside pure planning lanes. Opportunity: tie it to planning-only surfaces. Threat: startup surfaces inherit unnecessary logging context.
- `worktree-squad-gating-contract`: Strength: strong gate/evidence rules. Weakness: overlapping authority prose exists elsewhere. Opportunity: make this the single source of gate truth. Threat: operators read several similar contracts and infer inconsistent authority.
- `worktree-squad-loop-log-contract`: Strength: continuity requirements are explicit. Weakness: it is loaded into more surfaces than active worktree loops. Opportunity: keep it attached to actual loop owners. Threat: retrospective and loop obligations bleed outward.
- `worktree-squad-retrospective-template`: Strength: clear retrospective evidence structure. Weakness: it appears too early in some execution stacks. Opportunity: reserve it for retrospective ownership and late-gate evidence. Threat: execution packs carry retrospective bulk by default.
- `orbit-build-rerun-playbook`: Strength: sharp Orbit startup/execution discipline. Weakness: shared-pack softness can still dilute it. Opportunity: keep it narrow and authoritative. Threat: Orbit can be blamed for upstream orchestration issues.
- `orbit-attempt-improvement-loop`: Strength: explicit learning loop and historical preservation. Weakness: relies on stronger execution enforcement around it. Opportunity: pair it with harder execution routing. Threat: process claims outrun evidence if the execution pack is soft.
- `tools-and-constraints`: Strength: universal constraints are clear. Weakness: repeated loading adds little new signal in some stacks. Opportunity: keep it as one stable base essential. Threat: repetition turns hard constraints into background noise.

### Skill

- `codex-cli`: Strength: stable single execution-facing skill surface. Weakness: none in the pack graph itself. Opportunity: keep Samwise on one bounded tool surface. Threat: broad pack layering can make a stable skill appear more expansive than it is.

## Current Confidence Summary

- Base trust layer: `8.4`
- Hiring layer: `8.3`
- Orchestration/planning layer: `7.0`
- Worktree/execution layer: `7.3`
- Orbit-specific layer: `8.5`
- Skill layer: `9.2`
- Current overall confidence: `7.8`
- Current verdict: `caution`

## Red-Pen Recommendations

### Base Trust Layer

- Keep `trusted-partner-core` as the only Samwise default kit.
- Decide whether `samwise-daily-closeout` should remain universally inherited or become an explicit opt-in for narrow startup/review surfaces.

### Orchestration And Planning Layer

- Split `samwise-orchestration-core` into at least:
  - planning core
  - worktree oversight core
  - retrospective core
- Remove the `persona-hiring-*` essentials from orchestration once those narrower kit boundaries exist.
- Keep `multiagent-squad-planning-contract` and `squad-planning-log-contract` out of the coffee/startup surface unless the flow is explicitly planning-aware.

### Worktree And Execution Layer

- Make `worktree-squad-gating-contract` the canonical gate authority and trim overlapping gate prose from surrounding directives and intents.
- Revisit `gated-worktree-delivery` so retrospective concerns are only loaded when truly required for the active loop.

### Orbit-Specific Layer

- Harden `orbit-rerun-squad-execution` so specialist session routes are required or deterministically defaulted.
- Keep `orbit-build-rerun-core`, `orbit-build-rerun-playbook`, and `orbit-attempt-improvement-loop` narrow; fix the shared orchestration layer around them instead of broadening Orbit packs.

## Projected Confidence After Red-Pen

- Base trust layer: `8.8`
- Hiring layer: `8.8`
- Orchestration/planning layer: `8.6`
- Worktree/execution layer: `8.5`
- Orbit-specific layer: `9.0`
- Skill layer: `9.2`
- Projected overall confidence: `8.8`
- Projected verdict: `safe`

This pass says the Samwise pack graph is directionally strong, but still too eager to reuse one broad orchestration bundle across several distinct workflow families. The highest-value next move is not more persona text or more Orbit-specific prose; it is decomposing `samwise-orchestration-core`, then hardening the Orbit execution intent and trimming planning/closeout ballast from coffee mode and other narrow surfaces.
