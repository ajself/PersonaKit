# Orbit Milestone Dossiers

Status: Accepted
Owner: Samwise
Last Updated: 2026-03-18

## Purpose

Collect one refined planning dossier per Orbit milestone so an AI agent can work
deliberately instead of trying to collapse the roadmap into one rushed pass.

These dossiers sit under the Orbit planning stack and should be read as the next
layer of execution detail beneath:

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/Planning/Orbit-Proving-Loop.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`

## How To Use This Folder

Use each milestone directory as a dossier, not as a loose note.

Each milestone plan should answer:

- why the milestone exists
- what must already be true before it starts
- what is explicitly in scope and out of scope
- what work packets should run in order
- which persona should own each packet
- which subagents are safe and useful
- what evidence must exist before the milestone can close
- where the stop points are

## Frozen Dossier Standard

`M0` freezes the dossier standard in two places:

- `Docs/Orbit/Planning/Milestones/README.md`
  the meaning layer for dossier sections, artifact definitions, and planning
  boundaries
- `Docs/Orbit/Planning/Milestones/_Templates/`
  the reusable file shapes that later milestones should start from

Every serious milestone dossier should make all of these explicit:

- purpose and quality standard
- file map
- preconditions and scope freeze
- required inputs
- ordered execution packets
- subagent use pattern
- evidence package
- stop points
- exit and handoff

If a milestone needs more depth, add supporting artifacts without changing what
these core sections mean.

## Working Definitions

- milestone roadmap
  the top-level sequencing authority that defines milestone order, owners, and
  review gates across Orbit
- milestone dossier
  the per-milestone contract that turns the roadmap into bounded packets,
  evidence expectations, and stop points
- execution packet
  one bounded lane slice with one execution owner, one write scope, ordered
  work, validation expectations, and failure dispositions
- lane execution notes
  run-specific notes, logs, or checklists that explain how a packet was worked;
  they may add evidence but must not redefine the dossier contract
- evidence
  artifacts that prove quality, review, or failure handling rather than merely
  showing that activity happened
- stop point
  an explicit condition that forces AJ review or prerequisite resolution before
  work continues
- handoff
  the bounded packet returned to or sent from a lane, including grounding,
  write scope, evidence expectations, and closeout format

## Planning Status Lifecycle

- `Planned`
  the milestone README exists, but the dossier is not yet detailed enough to act
  as a closeout-ready contract
- `Draft`
  a supporting artifact is still being authored and should not be treated as the
  final review baseline on its own
- `Ready For Planning Closeout`
  the planning packet is coherent and ready for AJ review, but not yet approved
- `In Review`
  AJ or another named reviewer is actively evaluating the packet; do not treat
  it as approved while review is still open
- `Accepted`
  AJ approved the artifact or dossier as the active planning baseline for
  downstream work

Use `Accepted` only when the approval is recorded in a review packet, closeout
artifact, or equivalent note inside the planning stack.

## Planning Rules

- One active persona per lane.
- `samwise` remains the parent orchestrator unless a later contract says
  otherwise.
- Use subagents for bounded exploration, review, validation, and evidence
  synthesis; be conservative with parallel write-heavy work.
- If a milestone depends on a missing persona, stop and create or approve that
  persona before delegating the milestone.
- A milestone is not complete until its evidence package and AJ review gate are
  satisfied.

## Directory Map

- `_Templates/`
  reusable milestone templates derived from `M0` and `M1`
- `M0-Agentic-Execution-Scaffold/`
- `M1-Identity-And-Activation-Foundation/`
- `M2-Single-Workspace-macOS-Command-Center/`
- `M3-Canonical-Orbit-Server-And-Runtime/`
- `M4-Team-And-Squad-Collaboration/`
- `M5-Meeting-Promotion-And-Continuity/`
- `M6-Structured-Post-Objects-And-Decisions/`
- `M7-Workstream-Posts-And-Execution-Lanes/`
- `M8-Journaling-And-Memory-Candidate-Review/`
- `M9-Approved-Memory-And-Scoped-Retrieval/`
- `M10-Memory-Gardening-And-Cross-Workspace-Promotion/`
- `M11-iPhone-Client-And-Offline-Governance/`
- `M12-iPad-Meeting-Surface/`
- `M13-Platform-Operations-And-Hardening/`

## Current Next Planning Move

The first useful sequence now is:

1. use the accepted `M0` scaffold as the planning contract source
2. freeze the `M1` identity and activation contract
3. re-run `M2` as the first believable Orbit command-center checkpoint

Do not treat later milestone dossiers as permission to skip that sequence.

## Template Use

For future milestone expansion, start from:

- `Docs/Orbit/Planning/Milestones/_Templates/README.md`

Use the smallest relevant template set that still makes the milestone sharp,
reviewable, and quality-driven.
