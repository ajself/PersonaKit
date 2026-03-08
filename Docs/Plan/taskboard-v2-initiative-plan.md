# Taskboard V2 Initiative Plan

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Define the next version of Taskboard so it becomes genuinely useful and
credible as a scaled-down Trello-class planning experience for PersonaKit
Studio.

## Problem Statement

Taskboard v1 is functional but still shallow:

1. Limited ticket depth and board controls.
2. Low information density and workflow speed.
3. No AI-first mutation interface for reliable automated upkeep.
4. No rigorous competitive benchmark loop against Trello product behavior and
   UX patterns.
5. No screenshot-based visual quality gate to prevent generic, low-intent UI
   drift.

## V2 Outcomes

1. Taskboard supports practical daily initiative management.
2. AI can read and edit board state through a deterministic contract.
3. Product decisions are informed by source-backed Trello research artifacts.
4. Visual quality is measured with snapshot baselines and red-pen review gates.
5. Feature implementation starts only after AJ locks expected Trello-like
   features from research evidence.

## Scope

### In Scope

1. Taskboard v2 product definition and milestone plan.
2. AI-accessible board-state interface (read + write) with deterministic
   validation.
3. Market research lane for Trello:
   - web research
   - rigorous feature/UX comparison
   - published reference images (no generative images)
4. Snapshot-testing lane for Studio Taskboard visual quality.
5. Persona/session additions for multi-agent execution.
6. AJ feature-lock checkpoint after research and before implementation.

### Out Of Scope (for initial v2 kickoff)

1. Full Trello parity across every feature.
2. Multi-user real-time sync.
3. External integrations shipping in the same first v2 milestone.

## Workstreams

### W1: AI-Editable Taskboard Data Contract (Early Priority)

Goal:

- Make Taskboard state safely editable by Samwise/agents using deterministic
  operations.

Plan:

1. Confirm canonical store strategy:
   - Option A: workspace-local JSON file (current path)
   - Option B: SQLite with an adapter
2. Define mutation contract:
   - `create_ticket`
   - `edit_ticket`
   - `move_ticket`
   - `delete_ticket`
   - `create_lane`
   - `edit_lane`
   - `reorder_lane`
   - `delete_lane`
3. Add validation and conflict behavior:
   - stable IDs
   - lane/ticket referential integrity
   - deterministic ordering
4. Add an AI-facing execution surface:
   - CLI contract first
   - MCP/tooling path follow-up if needed

Deliverables:

1. Taskboard mutation schema/contract doc.
2. Validation rules + failure modes.
3. Manual and automated tests for mutation operations.

### W2: Trello Research Lane (Web + Published Artifacts)

Goal:

- Ground v2 decisions in evidence, not memory.

Research requirements:

1. Use web sources heavily.
2. Capture product behavior and UX patterns with source attribution.
3. Include published images from public resources (no generated images).
4. Build a comparison matrix:
   - feature set
   - interaction patterns
   - information architecture
   - keyboard efficiency
   - visual hierarchy
5. Record publication date and retrieval date for referenced sources where
   available.
6. Record image-usage and licensing notes in the image catalog.

Deliverables:

1. `Docs/Research/taskboard-trello-benchmark.md`
2. `Docs/Research/taskboard-trello-image-catalog.md` (source URLs, usage
   notes, licensing notes)
3. `Docs/Research/taskboard-trello-gap-matrix.md`

### W2.5: AJ Feature-Lock Checkpoint (Required Before Build)

Goal:

- Convert research into an explicit, AJ-approved “expected Trello features”
  list for Taskboard v2.

Plan:

1. Present research findings and ranked feature candidates.
2. Capture AJ’s expected feature set (must-have / should-have / later).
3. Freeze v2 scope using that approved list.
4. Record deferred features explicitly to prevent scope creep.

Deliverables:

1. `Docs/Plan/taskboard-v2-feature-lock.md`
2. Updated milestone scope in this plan.
3. Explicit no-build-before-lock note in TODO and gate model.

### W3: Visual Quality Gate With Snapshot Testing

Goal:

- Give the team “eyes” for repeatable visual regression detection.

Plan:

1. Integrate [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
   for Taskboard surfaces.
2. Add baseline snapshots for:
   - empty board
   - populated board
   - dense board
   - interaction states (selected lane, drag target, editor open)
3. Define review policy:
   - snapshot delta review required for Taskboard UI changes
   - red-pen pass required when major visual shifts occur

Deliverables:

1. Snapshot test target + fixtures.
2. Baseline image set checked into repo per convention.
3. Visual QA checklist and failure triage steps.

### W4: Taskboard V2 UX/Product Slice

Candidate v2 features:

1. Richer ticket metadata in card/detail view:
   - description
   - labels
   - due date
   - checklist
2. Filter/search/sort controls.
3. Faster keyboard flows and reduced click count.
4. Lane controls:
   - optional WIP limit
   - lane collapse
5. Optional activity trail for ticket updates.

## Persona + Session Additions

### Proposed Persona

- `taskboard-competitive-analyst`

Responsibilities:

1. Run market/competitor research with citation discipline.
2. Maintain Trello comparison matrix and gap scoring.
3. Provide recommendation briefs with clear tradeoffs and confidence level.

### Proposed Supporting Session

- `taskboard-competitive-research`
- `taskboard-visual-qa`
- `taskboard-ai-operations`

## Multiagent Execution Model

### Lane Ownership (Default)

1. `samwise`: orchestration, checkpoints, and cross-lane risk management.
2. `venture-product-steward`: research synthesis and feature prioritization.
3. `studio-interaction-quality-lead`: UX benchmark criteria and red-pen quality
   gates.
4. `architectural-editor`: AI-editable store contract and mutation safety
   boundaries.
5. `studio-reliability-engineer`: mutation integrity, persistence edge cases,
   and regression-risk checks.
6. `pack-gardener` (Rosie): planning/log hygiene and decision traceability.

### Parallelization Rules

1. Run research lane and AI-contract lane in parallel.
2. Run snapshot-lane scaffolding in parallel with research synthesis.
3. Block UI/feature implementation lanes until `W2.5` feature lock is approved.
4. Keep disjoint write scopes for parallel workers.

## Milestone Plan

### TV2-M1: Foundations

1. Lock v2 scope and acceptance criteria.
2. Define AI mutation contract and storage decision.
3. Establish research and snapshot-testing scaffolding.
4. Complete `W2.5` AJ feature lock from research outputs.

Exit criteria:

1. AI-editable contract is documented and approved.
2. Research plan + artifact templates are approved.
3. Snapshot test scaffolding runs in CI/local tests.
4. AJ expected feature list is approved and frozen in a dedicated lock artifact.

### TV2-M2: Execution

1. Implement AI mutation interface with tests.
2. Complete Trello research corpus and gap matrix.
3. Implement first v2 UX slice (metadata + filter/search baseline).

Exit criteria:

1. AI can update Taskboard deterministically via approved interface.
2. Research artifacts are complete and source-backed.
3. v2 slice passes snapshot + interaction-quality review.

### TV2-M3: Hardening + Pilot

1. Pilot real initiative usage in Taskboard.
2. Capture friction metrics and revise workflow.
3. Decide rollout threshold for “useful in practice.”

Exit criteria:

1. Pilot evidence shows reduced planning friction.
2. No blocker-level interaction defects in red-pen review.
3. Visual regressions are controlled through snapshot gate.

## Gate Model

1. `G1 Product Definition`: v2 scope and acceptance locked.
2. `G2 AI Contract`: mutation API/store/validation approved.
3. `G3 Research Corpus`: Trello benchmark artifacts complete.
4. `G3.5 Feature Lock`: AJ-approved expected Trello feature list frozen.
5. `G4 Visual QA`: snapshot baselines and policy active.
6. `G5 Pilot Ready`: TV2-M2 complete with no blocker findings.

Hard rule:

1. No Taskboard feature implementation starts before `G3.5` passes.

## Verification Plan

1. Run PersonaKit validation after pack/session additions.
2. Run Taskboard snapshot tests and keep baselines current.
3. Run interaction-quality red-pen pass after each milestone.
4. Validate research artifact completeness with source-link checks.

## Related Docs

1. `Docs/Plan/admin-ticket-planning-feature-brief.md`
2. `Docs/Plan/taskboard-parity-polish-pass-2.md`
3. `Docs/Plan/TODO.md`
