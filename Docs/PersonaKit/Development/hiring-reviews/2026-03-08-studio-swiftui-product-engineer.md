# Studio SwiftUI Product Engineer Reverse Interview

Status: Complete
Owner: AJ
Last Reviewed: 2026-03-08

Session: `samwise-persona-hiring`
Candidate: `studio-swiftui-product-engineer`

## Role Context And Required Capabilities

Assess whether `studio-swiftui-product-engineer` is qualified to own bounded
Taskboard board and card SwiftUI implementation work aimed at credible
Trello-like parity.

Must-have capabilities:

1. Strong SwiftUI product implementation judgment for board and card flows.
2. Bounded delivery behavior inside declared Taskboard UI write scope.
3. Respect for parity review, architectural, and reliability guardrails.
4. Clear verification and handoff notes after each implementation slice.
5. No hidden scope expansion into persistence or architecture redesign.

## Evidence References

1. `.personakit/Packs/personas/studio-swiftui-product-engineer.persona.json`
2. `.personakit/Packs/intents/implement-taskboard-board-card-parity.intent.json`
3. `.personakit/Packs/directives/implement-taskboard-board-card-parity.directive.json`
4. `.personakit/Sessions/taskboard-board-card-build.session.json`
5. `.personakit/Packs/kits/taskboard-parity-core.kit.json`
6. `.personakit/Packs/essentials/taskboard-board-card-parity-checklist.md`
7. `.personakit/Packs/essentials/worktree-squad-gating-contract.md`
8. `Docs/Plan/taskboard-trello-parity-execution-charter.md`

## Strengths

1. Persona responsibilities are tightly aligned to board and card SwiftUI product work.
2. Non-goals explicitly prevent persistence redesign and speculative architecture drift.
3. Intent and directive are bounded to declared Taskboard write scope with review stop points.
4. Default kits provide parity checklist, Swift style guidance, and partner guardrails.
5. Required output shape includes verification notes and residual rough-edge handoff detail.

## Gaps By Severity

- Medium: Real-world calibration on dense Taskboard interaction slices is still unproven.
- Low: The role may eventually benefit from a dedicated Taskboard implementation benchmark corpus once multiple parity slices have shipped.

## Unknowns And Assumptions

1. Assumption: the current Taskboard UI file split remains stable enough for bounded ownership.
2. Unknown: how much parity feel can be improved without eventual deeper UI decomposition.

## Confidence Score And Threshold

- Domain understanding: `4/5`
- Delivery planning quality: `5/5`
- Risk and guardrail discipline: `4/5`
- Collaboration and handoff clarity: `4/5`
- Tooling and workflow coverage: `5/5`

Total: `22/25`
Confidence: `88%`
Threshold: `80%`

## Verdict

`qualified`

Rationale: the candidate has the right bounded implementation identity, clear
parity-oriented scope, and enough workflow surface to contribute safely on the
Board Experience Squad now.

## Missing Artifact Recommendations By Type

- essentials: none required
- kits: none required
- intents: none required
- directives: none required
- sessions: none required

## First Implementation Step

Use `taskboard-board-card-build` for the next bounded Taskboard board interaction
slice and require verification notes plus a parity-review handoff before any
commit package.
