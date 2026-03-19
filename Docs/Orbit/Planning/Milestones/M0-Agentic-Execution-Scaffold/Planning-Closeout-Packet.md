# M0 Planning Closeout Packet

Status: Accepted
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Package the final `M0` review asks so AJ can approve or redirect the scaffold
without reconstructing the whole planning thread.

## What `M0` Freezes

- milestone dossier meaning and section standard through
  `Docs/Orbit/Planning/Milestones/README.md`
- reusable dossier and execution-packet templates through
  `Docs/Orbit/Planning/Milestones/_Templates/`
- delegated handoff packet requirements, including grounding, write scope,
  commit-authority posture, stop points, and closeout return format
- approved Orbit stack posture through `M3`
- one explicit owner and review ring for every roadmap milestone, with blocked
  statuses where persona coverage is still missing
- the first-checkpoint `ProdDoc` decision: product-facing label mapped to
  `venture-product-steward`

## Decisions Closed In `M0`

### 1. `ProdDoc` identity for the first checkpoint

- approved posture: keep `ProdDoc` as the visible collaborator label
- identity mapping: `ProdDoc` maps explicitly to `venture-product-steward`
- downstream effect: `M1` and `M2` may rely on that alias without inventing a
  new persona now

### 2. Dossier freeze level

- approved posture: treat `Docs/Orbit/Planning/Milestones/README.md` plus the
  template library as the frozen dossier standard
- allowed future change: additive refinement only; do not redefine the meaning
  of existing dossier sections

### 3. Early Orbit stack posture

- `M1` and `M2`: `Swift` + `SwiftUI` on macOS
- `M3`: `Swift` + `Vapor` + `Postgres`
- deployment posture through `M3`: self-hosted, private infrastructure,
  monolith-first
- construction window: implementation is authorized through `M3` only, then
  pauses until AJ restarts it

## Decisions Staged As Prerequisites

### Missing personas not created during `M0`

- `orbit-meeting-coordinator`
  required before delegating `M4`, `M5`, or full `M12` coordinator work
- `orbit-memory-gardener`
  required before delegating `M8`, `M9`, or `M10`
- `orbit-platform-operator` or `orbit-server-steward`
  one of these must exist before delegating `M13`

### Conditional persona reassessment

- `worktree-squad-lead` is acceptable for the first cut of `M7`
- reassess whether `orbit-workstream-runner` is needed before `M7`
  implementation begins in earnest

## Approval Asks For AJ

Approve or redirect these `M0` outcomes:

1. the milestone role map and blocked-status posture in
   `Persona-Coverage-Matrix.md`
2. the frozen `ProdDoc` -> `venture-product-steward` alias for the first
   checkpoint
3. the approved stack posture and construction boundary in
   `Tech-Stack-Posture.md`
4. the staged missing-persona plan instead of creating those personas now

## AJ Review Outcome

- `1` approved: the milestone role map and blocked-status posture
- `2` approved: the frozen `ProdDoc` -> `venture-product-steward` alias for the
  first checkpoint
- `3` approved: the `M0` through `M3` stack posture and construction boundary
- `4` approved: the staged missing-persona plan instead of creating those
  personas during `M0`

## What Becomes Unblocked If AJ Accepts This Packet

- `M1` can proceed with a fixed collaborator identity model and activation trace
  contract
- `M2` can proceed with a stable founding-roster naming rule
- `M3` can proceed without reopening the foundational client, server, database,
  deployment, or worktree-boundary choices

## What Stays Blocked After `M0`

- no new persona creation without AJ review
- no delegation of `M4`, `M5`, `M8`, `M9`, `M10`, `M12`, or `M13` into
  persona-missing execution lanes
- no implementation beyond `M3` until AJ explicitly restarts construction
- no milestone execution on repository `main` or the main worktree

## Review Pass

AJ should be able to answer all of these from this packet plus the linked
artifacts:

- is the role map honest about what is covered versus blocked?
- is the first-checkpoint `ProdDoc` alias precise enough for `M1` and `M2`?
- is the stack posture explicit enough to stop agentic stack drift?
- are the staged personas named early enough to stop hidden persona gaps later?

## Recommended Handoff If Approved

- hand off to `M1` with the frozen first-checkpoint collaborator identity model
- hand off to `M2` with the approved founding-roster alias and no reopened stack
  decisions
