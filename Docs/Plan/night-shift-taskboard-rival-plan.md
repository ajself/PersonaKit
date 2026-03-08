# Night Shift Taskboard Rival Plan

Status: Active  
Owner: AJ + Samwise  
Last Reviewed: 2026-03-08

## Purpose

Provide a dependency-linked night-shift execution system so Samwise can
orchestrate multi-agent delivery in small, verifiable increments toward a
Trello-rival Taskboard experience.

## Current Execution Snapshot (2026-03-08)

1. `NS0` foundation landed:
   - telemetry model + JSONL/report builder committed in `9242fcb`
2. First `NS1` throughput foundations landed:
   - one-click previous/next lane movement
   - in-lane drag reorder targeting
3. Remaining focus:
   - complete `NS0` evidence/report loop
   - continue `NS1` keyboard-speed paths before `NS2`
   - use the now-complete snapshot matrix as the visual regression lane during
     parity work
4. Staffing and parity charter updates landed:
   - Taskboard now has dedicated `studio-swiftui-product-engineer` and `taskboard-parity-designer` roles
   - Samwise delegated commit approval is active only for this initiative scope
5. Snapshot lane milestone landed:
   - required coverage is now `7/7`
   - editor-open states are covered with a board-plus-editor harness so visual
     evidence includes the editing surface rather than a missing macOS sheet
6. Second `NS1` throughput slice landed:
   - cards now support inline quick edit for title, assignees, and labels
   - snapshot evidence includes a dedicated inline quick-edit state

## Branch Strategy

1. Integration branch: `codex/night-shift`.
2. One objective branch per plan milestone from `codex/night-shift`:
   - `codex/night-shift/ns0-orchestration`
   - `codex/night-shift/ns1-interaction-throughput`
   - `codex/night-shift/ns2-visual-feedback`
   - `codex/night-shift/ns3-ai-ops-and-hardening`
3. Morning review compares each objective branch (or squashed result) against
   `main` after rebase.

## Agent Orchestration Model (Agile)

Role clarity:

1. In this plan, `mutation` means deterministic changes to Taskboard state
   (lane/ticket create/edit/move/delete), not “writing code”.
2. Code authoring responsibility is explicit and separate:
   - `studio-feature-implementer`: writes product/UI implementation code.
   - `studio-reliability-engineer`: writes/updates tests and regression guards.

Cadence per night shift:

1. Define one sprint goal for a single milestone (`NS0`..`NS3`).
2. Decompose into smallest tickets with explicit acceptance criteria.
3. Assign lanes:
   - `samwise`: orchestration, risk control, merge gate.
   - `studio-feature-implementer`: implementation owner for scoped tickets.
   - `venture-product-steward`: prioritization, product acceptance, and
     outcome fit.
   - `studio-product-designer`: interaction design decisions and visual
     direction.
   - `studio-interaction-quality-lead`: interaction and visual QA.
   - `architectural-editor`: schema/mutation/API boundaries.
   - `studio-reliability-engineer`: tests, regressions, failure modes.
4. Run short implementation loops:
   - build -> test -> snapshot -> product review -> design review -> adjust.
5. End with a morning brief: shipped, blocked, and next ticket queue.
6. At assignment closeout, run a retrospective (`what went well`, `what did
   not`, `open questions`, `improvements`, and `next action items`) and append
   contract-compliant retrospective logs.
7. After closeout, run Rosie retrospective gardening to mine diary +
   retrospective artifacts and propose iteration improvements.

Definition of Done for any ticket:

1. Behavior implemented and manually verifiable.
2. Deterministic tests added/updated.
3. Snapshot evidence updated if UI changed (PNG baseline artifacts).
4. Product + design QA signoff recorded for user-facing changes.
5. No blocker findings in red-pen notes.

## Night Shift Reliability Guardrails

Goal:

- Prevent idle/stall loops from permission or environment blockers.

Rules:

1. Run a preflight at shift start:
   - `git status`
   - one fast test target
   - one build command
2. If a command requires elevated permission:
   - request escalation once with a clear reason
   - immediately switch to non-blocked queued work while waiting
3. If escalation is denied or unavailable:
   - log blocked command + why it is blocked
   - continue all remaining tasks that do not require escalation
4. Never end a shift with “stuck on permission” as the only outcome.
5. Morning brief must include:
   - `blocked-by-permission` section (if any)
   - exact commands attempted
   - fallback work completed during the block

## Linked Plan Series

## NS0: Orchestration + Instrumentation Foundation

Goal:

- Make night-shift execution reliable and inspectable before deeper UX work.

Depends on:

- Existing Taskboard v2 baseline on `main`.

Scope:

1. Add `Taskboard` UX telemetry hooks (event logs for key interactions) at:
   - `.personakit/Taskboard/night-shift/interaction-events.jsonl`
2. Add explicit ticket workflow states needed for throughput measurement.
3. Add nightly report template and artifact location:
   - `Docs/Plan/templates/taskboard-night-shift-report-template.md`
   - `.personakit/Taskboard/night-shift/interaction-report.md`

Verifiable outcomes:

1. Interaction events are emitted for at least:
   - create ticket
   - edit ticket
   - move ticket (all variants)
   - reorder ticket
   - collapse/expand lane
2. One deterministic report generated from real interaction data at
   `.personakit/Taskboard/night-shift/interaction-report.md`.
3. `swift test` and `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio` pass.

## NS1: Interaction Throughput Core

Goal:

- Cut friction in core board operations until common flows feel immediate.

Depends on:

- NS0 completed and reporting available.

Scope:

1. In-lane drag reorder with clear insertion feedback.
2. One-click ticket progress actions (next/previous lane, complete lane step).
3. Inline quick edit for title/assignees/labels.
4. Keyboard-first path for triage and movement.

Verifiable outcomes:

1. Three canonical flows completed with <= 50% of baseline clicks:
   - triage inbox ticket to in-progress
   - reprioritize card order in a lane
   - handoff to review lane
2. Snapshot diffs approved for default + dense board states.
3. No regression in mutation/search tests.

## NS2: Visual + Feedback Polish

Goal:

- Raise perceived quality and clarity to “product-grade” rather than “internal tool”.

Depends on:

- NS1 interaction throughput gains.

Scope:

1. Strong drag/drop affordances and motion continuity.
2. Better card hierarchy (title/meta/actions readability at glance).
3. Lane health signals (WIP pressure, due risk, blocked visibility).
4. Skeleton/loading/empty states tuned for confidence.

Verifiable outcomes:

1. Red-pen score >= 88/100 with no blocker findings.
2. Required snapshot matrix reaches 7/7 scenarios.
3. At least one accessibility pass completed (keyboard, contrast, focus order).

## NS3: AI Ops + Hardening

Goal:

- Make Taskboard consistently operable by Samwise/agents and stable under nightly iteration.

Depends on:

- NS2 visual and interaction acceptance.

Scope:

1. Expand mutation contract coverage for new interaction actions.
2. Add deterministic conflict/error handling for concurrent AI edits.
3. Add AI-maintained initiative status loop with strict validation.
4. Add “safe automation” checks so AI updates never corrupt board state.

Verifiable outcomes:

1. Contract tests cover all supported mutation operations and new fields.
2. Replay determinism test passes for repeated command sequences.
3. Morning status sync can be produced directly from Taskboard state.

## Tonight Handoff (Filled)

Night Shift Handoff (Samwise)

1. Goal by morning:
- Complete NS0 planning package + first implementable ticket list, then start
  the highest-value NS1 ticket only if NS0 exits green.

2. Priority order:
1. Finalize NS0 ticket backlog with acceptance criteria and branch plan.
2. Implement one NS1 throughput improvement ticket end-to-end.
3. Produce morning brief with evidence links and blocker notes.

3. Guardrails:
- Samwise may approve commits only inside the active Taskboard initiative worktree under `samwise-feature-commit-approved`; main-affecting integration still pauses for AJ release approval.
- No scope expansion beyond NS0/first NS1 ticket.
- If blocked >15 minutes, stop and log blocker + options.

4. Allowed actions:
- [x] code edits
- [x] tests/builds
- [x] docs updates
- [x] snapshot updates

5. Deliverables:
- Updated files
- Validation results
- Proposed commit message(s) only (no commit unless approved)
- Next 3 actions for resume

## Night Shift Progress (2026-03-07 Checkpoint)

Completed:

1. `NS0` telemetry/report foundation is implemented:
   - interaction events JSONL writer/reader + deterministic report builder
   - Taskboard persistence wiring for events + report
   - Taskboard header action to generate report
   - deterministic telemetry tests
2. First `NS1` throughput ticket is implemented:
   - one-click ticket lane movement (`previous` + `next`) on card chrome
   - in-lane drag reorder now supports ticket-level drop targeting
   - visual insertion targeting via focused drop outlines
   - lane adjacency helper + unit tests
3. Validation checkpoints pass:
   - `swift test`
   - `swift test --filter TaskboardSnapshotTests`
   - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio`
4. Squad-leader coordination test contract is defined:
   - Samwise remains primary orchestrator for agent management and gate decisions
   - Worktree Squad Lead accelerates implementation/product loops inside bounded lane scope
   - success requires evidence that both roles collaborated to move a gated objective forward

Open:

1. Generate a real-data night report artifact after interactive board usage:
   - `.personakit/Taskboard/night-shift/interaction-report.md`
2. Continue `NS1` with keyboard-first triage/movement flow.

## Trello Reference Notes

Used to align expectations for interaction behavior:

1. Trello keyboard shortcuts: [support.atlassian.com](https://support.atlassian.com/trello/docs/keyboard-shortcuts-in-trello/)
2. Moving cards between lists and boards: [support.atlassian.com](https://support.atlassian.com/trello/docs/moving-cards/)
3. Markdown support in card descriptions/comments: [support.atlassian.com](https://support.atlassian.com/trello/docs/formatting-text-with-markdown/)
