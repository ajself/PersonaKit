# Orbit Docs

Status: Active
Owner: AJ
Last Reviewed: 2026-03-10

## Purpose

Provide the documentation map for Orbit as the current forward product
direction in this repository.

Orbit is the platform/product direction.
PersonaKit is the engine inside Orbit.

## Start Here

If you want the fastest understanding of what Orbit is and what we are doing
now, read:

1. [Vision/orbit-platform-vision-and-system-design.md](./Vision/orbit-platform-vision-and-system-design.md)
2. [Planning/Orbit-Proving-Loop.md](./Planning/Orbit-Proving-Loop.md)
3. [Planning/Orbit-macOS-Command-Center.md](./Planning/Orbit-macOS-Command-Center.md)
4. [Planning/Orbit-Execution-Plan.md](./Planning/Orbit-Execution-Plan.md)

## Vision Docs

- [Vision/orbit-platform-vision-and-system-design.md](./Vision/orbit-platform-vision-and-system-design.md)
  The richest single-document Orbit pitch, role model, use-case map, and system
  design synthesis.

## Active Planning Docs

- [Planning/Orbit-Proving-Loop.md](./Planning/Orbit-Proving-Loop.md)
  The active implementation-facing proving-loop plan.
- [Planning/Orbit-macOS-Command-Center.md](./Planning/Orbit-macOS-Command-Center.md)
  The approved product-facing companion draft.
- [Planning/Orbit-Execution-Plan.md](./Planning/Orbit-Execution-Plan.md)
  The execution bridge that records what Orbit is actually doing next.

## Active Execution Docs

- [Execution/Orbit-Build-Rerun-Checklist.md](./Execution/Orbit-Build-Rerun-Checklist.md)
  The startup and closeout playbook for a fresh `main`-based Orbit lane rerun.
- [Execution/Orbit-Product-Acceptance-Checklist.md](./Execution/Orbit-Product-Acceptance-Checklist.md)
  The required first-checkpoint product bar before Orbit can be called
  `review-ready` or `MVP candidate`.
- [Execution/Orbit-Foundation-Lane.md](./Execution/Orbit-Foundation-Lane.md)
  The historical first-run MVP lane contract for `codex/orbit-foundation`.
- [Execution/2026-03-09-orbit-foundation-retrospective.md](./Execution/2026-03-09-orbit-foundation-retrospective.md)
  The first Orbit foundation execution retrospective and process report.
- [Execution/2026-03-10-orbit-1-rerun-prep.md](./Execution/2026-03-10-orbit-1-rerun-prep.md)
  The active staged rerun note for the next manifest-approved fresh-main Orbit
  attempt.
- [Execution/Orbit-Attempt-1-Lane.md](./Execution/Orbit-Attempt-1-Lane.md)
  The generated lane contract for the current `codex/orbit-1` execution lane.
- [Execution/Orbit-Retrospective-Policy.md](./Execution/Orbit-Retrospective-Policy.md)
  The required Orbit retrospective closeout policy, including Starfish cadence
  and synthesis rules.
- [Execution/Orbit-Retrospective-Methodology-Comparison.md](./Execution/Orbit-Retrospective-Methodology-Comparison.md)
  The head-to-head plan for comparing roundtable and fan-out Orbit
  retrospectives.
- [Execution/retrospectives/README.md](./Execution/retrospectives/README.md)
  Runnable Orbit retrospective packet templates for evidence, roundtable,
  fan-out, and comparison scoring.
- [Execution/2026-03-09-orbit-foundation-rerun-prep.md](./Execution/2026-03-09-orbit-foundation-rerun-prep.md)
  Historical first-attempt carry-forward notes preserved as rerun input, not as
  the active startup surface.

PersonaKit execution session for the rerun:

- `samwise-orbit-rerun-startup`
  The Samwise startup session for staging the rerun, validating the lane
  contract from the repo root, and freezing the execution handoff before the
  live lane begins.
- `samwise-orbit-rerun-execution`
  The Samwise execution session for materializing the lane worktree if needed,
  then routing Orbit implementation, product review, interaction review,
  validation review, and retrospective closeout through distinct specialist
  sessions once the lane is live.

## Architecture And RFCs

- [Architecture/Architecture-Index.md](./Architecture/Architecture-Index.md)
  Recommended reading order for Orbit architecture.
- [RFCs/README.md](./RFCs/README.md)
  Orbit RFC index and status guidance.

Use the RFCs as architectural guardrails.
Do not treat them as the default daily work queue unless an active planning
document explicitly sends you there.

## Meeting History

- [Meeting Notes/](./Meeting%20Notes/)

Meeting notes are the decision trail.
They are historical conversation records, not the primary implementation
contract once planning docs have been promoted into `Planning/`.

## Relationship To The Rest Of `Docs/`

- `Docs/Orbit/` is the current forward product direction.
- `Docs/PersonaKit/` and the root `README.md` describe the current PersonaKit
  engine/repository operating model.
- `Docs/MCP/` contains current MCP usage and troubleshooting guidance.
- `Docs/Archive/PersonaKit/` contains earlier PersonaKit planning and research
  material.
- `Docs/Archive/MCP/` contains historical MCP planning material.
