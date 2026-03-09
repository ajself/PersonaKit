# Taskboard V2 Initiative Plan

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-08

## Purpose

Define the active Taskboard initiative so PersonaKit Studio reaches
`Board + Card Parity`: a human user should be able to use the board and
card-detail experience and reasonably think it is Trello.

## Problem Statement

Taskboard has strong foundations, but the current experience still falls short
of the intended Trello impression:

1. Board interactions are improving, but keyboard-first triage and movement are
   still more awkward and click-heavy than they should be.
2. Card-detail depth and board-to-detail continuity still need polish.
3. Snapshot baseline coverage is now complete, but parity review and diff-review
   discipline still need to prove the product clears the Trello bar.
4. AI-operable mutation infrastructure exists in part, but the callable upkeep
   surface is not yet finished.
5. The initiative needs explicit squad staffing and tighter parity-specific
   acceptance criteria.

## Outcomes

1. Taskboard reaches credible board-and-card parity for the current scope.
2. AI can read and edit board state through a deterministic approved contract.
3. Product and visual decisions remain grounded in source-backed Trello research.
4. Visual quality is measured with snapshot baselines and parity-focused red-pen
   review gates.
5. The initiative can be executed through bounded squads with explicit review,
   logging, and retrospective loops.

## Scope

### In Scope

1. Taskboard board and card-detail parity for the current initiative.
2. AI-accessible board-state interface (read + write) with deterministic
   validation.
3. Trello research and image-backed parity references.
4. Snapshot-testing and accessibility review for Taskboard board/card states.
5. Persona and session additions required for the squad execution model.
6. Initiative-scoped delegated commit approval experiment for Samwise inside the
   active Taskboard worktree only.

### Out Of Scope

1. Full Trello parity across every view and integration.
2. Multi-user real-time sync.
3. Shipping unrelated product surfaces in the same initiative.
4. Expanding delegated commit approval to other branches before retrospective
   review.

## Core Workstreams

### W1: AI-Editable Taskboard Contract

Goal:

- Make Taskboard state safely editable by Samwise and approved agents using
  deterministic operations.

Deliverables:

1. `Docs/Plan/taskboard-ai-mutation-contract.md`
2. Stable validation and failure modes
3. Contract tests for supported mutation operations
4. Callable local surface for read/write upkeep loops

### W2: Trello Research And Parity References

Goal:

- Ground parity claims in evidence instead of memory.

Deliverables:

1. `Docs/Research/taskboard-trello-benchmark.md`
2. `Docs/Research/taskboard-trello-image-catalog.md`
3. `Docs/Research/taskboard-trello-gap-matrix.md`
4. Explicit board-and-card parity checklist used by product and visual QA

### W3: Visual Quality Gate

Goal:

- Give the team deterministic “eyes” for parity and regression review.

Deliverables:

1. Snapshot baselines for all required board/card scenarios
2. Documented diff-review policy for Taskboard UI changes
3. Accessibility review evidence for supported board/card workflows

### W4: Squad Staffing And Delivery Model

Goal:

- Make multi-agent delivery faster than manual micromanagement while staying
  safe and reviewable.

Deliverables:

1. Qualified `studio-swiftui-product-engineer`
2. Qualified `taskboard-parity-designer`
3. Worktree squad delivery, oversight, and retrospective loops
4. Partner-trust policy updated for the initiative-scoped delegated commit
   experiment

## Multiagent Execution Model

### Squad Ownership

1. `samwise`: orchestration, gate decisions, commit-package approval within the
   current initiative scope, and cross-squad continuity
2. `venture-product-steward`: parity checklist and milestone acceptance framing
3. `studio-swiftui-product-engineer`: bounded Taskboard board/card implementation
4. `taskboard-parity-designer`: Trello-like parity review for board/card flows
5. `studio-interaction-quality-lead`: red-pen UX gates and blocker detection
6. `architectural-editor`: AI-editable store and contract boundaries
7. `studio-reliability-engineer`: mutation integrity, persistence, and
   deterministic regression checks
8. `pack-gardener` (Rosie): retrospective gardening and continuity hygiene

### Parallelization Rules

1. Only one coding squad may actively edit the hot Taskboard UI surface at a
   time.
2. Sidecar review squads may run in parallel when they do not mutate the same
   hot files.
3. UI implementation remains blocked from broad scope expansion until parity and
   acceptance criteria stay explicit.

## Milestone Plan

### P0: Staffing Readiness

1. Create missing specialist personas and sessions.
2. Run reverse-interview loops until each new role is `qualified` at `>= 80`.
3. Wire the squad delivery model and delegated-commit experiment into active
   contracts and plan docs.

Exit criteria:

1. Both new personas are qualified.
2. Squad sessions export cleanly and validate.
3. Delegated commit experiment is explicitly bounded to the current initiative.

### P1: Research + Lock Reset

1. Replace narrower “scaled-down Trello-class” framing with explicit
   `Board + Card Parity` acceptance.
2. Refresh milestone acceptance criteria against the Trello research corpus.
3. Keep out-of-scope boundaries explicit.

Exit criteria:

1. Parity checklist is concrete enough to settle disagreements.
2. Milestone acceptance criteria derive from the parity bar.

### P2: Board Interaction Parity

1. Finish the current NS0 evidence/report loop.
2. Expand snapshots from `2/7` to `7/7`.
3. Continue NS1 throughput work including inline quick edit and keyboard-first
   triage/movement.
4. Lower click depth and improve movement clarity until the board feels fast.

Exit criteria:

1. Required snapshot coverage is complete.
2. Board interaction review has `0` blocker findings.

### P3: Card Detail Parity

1. Raise card-detail depth and continuity.
2. Tighten board-to-detail and detail-to-board transitions.
3. Make metadata and discussion surfaces feel like one coherent product.

Exit criteria:

1. Card-detail parity review has `0` blocker findings.
2. Card workflows no longer feel secondary or bolted on.

### P4: Visual + Accessibility Parity

1. Run parity-focused visual review against Trello references.
2. Complete keyboard, focus, label, and contrast review.
3. Remove remaining template-app or AI-scaffolding feel.

Exit criteria:

1. Visual QA says the board/card experience clears the Trello-impression bar.
2. Accessibility pass is complete for supported flows.

### P5: AI-Operable Parity

1. Finish the approved callable local mutation/read surface.
2. Enforce deterministic behavior, idempotency, optimistic concurrency, and
   stable errors.
3. Make the surface usable in real Samwise-led upkeep loops.

Exit criteria:

1. Samwise can update Taskboard state through the approved local surface.
2. Outputs are deterministic and auditable.

### P6: Closeout

1. Clear active Taskboard items from `Docs/Plan/TODO.md`.
2. Archive no-longer-active Taskboard planning artifacts.
3. Run squad retrospectives and Rosie gardening.
4. Review the delegated commit experiment.

Exit criteria:

1. No dangling active Taskboard tasks remain.
2. Retrospective and recommendation artifacts exist for the initiative.

## Related Docs

1. `Docs/Plan/taskboard-trello-parity-execution-charter.md`
2. `Docs/Plan/taskboard-v2-feature-lock.md`
3. `Docs/Plan/taskboard-ai-mutation-contract.md`
4. `Docs/Plan/taskboard-v2-snapshot-lane.md`
5. `Docs/Plan/night-shift-taskboard-rival-plan.md`
