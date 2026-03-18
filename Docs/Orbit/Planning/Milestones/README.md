# Orbit Milestone Dossiers

Status: Draft
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

The first useful sequence remains:

1. close `M0`
2. freeze the `M1` identity and activation contract
3. re-run `M2` as the first believable Orbit command-center checkpoint

Do not treat later milestone dossiers as permission to skip that sequence.

## Template Use

For future milestone expansion, start from:

- `Docs/Orbit/Planning/Milestones/_Templates/README.md`

Use the smallest relevant template set that still makes the milestone sharp,
reviewable, and quality-driven.
