# Orbit Execution Plan

Status: Draft
Owner: Samwise
Workspace: Orbit
Last Updated: 2026-03-09

## Purpose

Record what Orbit is actually doing next.

This document exists to bridge the gap between:

- long-range RFC direction
- approved planning artifacts
- the first concrete engineering moves

It should answer:

- what milestone we are building first
- what counts as done for that milestone
- what is explicitly out of scope
- what the first implementation tasks should be
- which RFCs matter now versus later

## Inputs

This execution plan builds on:

- `Docs/Orbit/Planning/Orbit-Proving-Loop.md`
- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
- Meeting 002 closeout decisions

## Current Decision

Orbit should move forward through execution planning, not another broad RFC
review pass.

The RFCs are still important, but they should now act as guardrails for the
first build rather than the main work queue.

## First Milestone

The first execution milestone is:

**Phase 1 + Phase 2 + minimal Phase 3**

In practical terms, that means:

1. Workspace and roster foundation
2. Durable conversation loop
3. Just enough lightweight meeting and activation trace behavior to make Orbit
   feel structurally different from ordinary chat

This is the first engineering checkpoint that matters most.

## Milestone Definition Of Done

The first milestone is complete when AJ can:

1. open the Orbit workspace in the macOS app
2. see the Orbit workspace context clearly
3. see AJ, Samwise, and ProdDoc as durable participants
4. start or continue a conversation thread
5. close and reopen the app without losing that thread
6. address one participant or trigger a lightweight multi-participant exchange
7. see who responded
8. inspect lightweight activation trace information for the response

At that point, Orbit should begin to feel like a workspace command center with
persistent collaborators rather than a chat app with personas layered on top.

## Explicitly Out Of Scope For This Milestone

Do not treat these as first-milestone requirements:

- summary generation
- memory candidate review
- memory reuse
- iPhone or iPad clients
- deep team or squad management UI
- cross-workspace learning
- automated gardening
- elaborate meeting visualization
- analytics-heavy trace inspection

Those belong to later phases unless a blocker forces one small piece earlier.

## Best First Engineering Step

The best first engineering step is:

**define the minimum durable runtime model and persistence boundary for the
first checkpoint**

That model should cover at least:

- workspace
- participant
- conversation thread
- message
- activation record

If this layer is unclear, the UI and meeting behavior will drift quickly.

If this layer is clear, the first macOS surface can be built with much less
guesswork.

## First Task Sequence

The first implementation tasks should be:

1. Define the minimum local runtime entities and persistence boundary for:
   - workspace
   - participant
   - conversation thread
   - message
   - activation record
2. Decide the smallest acceptable local persistence approach for the checkpoint
   build.
3. Build the macOS workspace shell that shows:
   - workspace context
   - founding-group roster
   - active conversation surface
4. Implement durable conversation creation, loading, and visible speaker
   attribution.
5. Implement participant addressing plus a lightweight multi-participant
   interaction path.
6. Persist activation context and expose it through a lightweight trace
   affordance in the UI.
7. Run a checkpoint review against the milestone definition of done.
8. Run the required Orbit retrospective closeout defined in
   `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md` before touching summary
   or memory features or calling the milestone closed.

## Comparison-Grade Rerun Contract

The next fresh `main`-based Orbit worktree is not just repeating the build.

It is repeating the full execution exercise at a comparison-grade standard.

That means the next run must be able to prove:

1. the feature slice that was built
2. the product quality that was reviewed
3. the process behavior that actually occurred
4. the persona fidelity that was actually exercised

Do not rely on thread history for these rules.

Treat this document, the implementation breakdown, the rerun checklist, and the
product acceptance checklist as the active contract.

## Proposed First Squad

The first execution squad should stay small and role-clear:

1. `Samwise`
   Own orchestration, scope discipline, review pauses, and handoff quality.
2. `Venture Product Steward`
   Own milestone framing, product tradeoffs, and checkpoint acceptance against
   the command-center surface.
3. `Senior SwiftUI Engineer`
   Own the first runtime plus macOS shell implementation pass.
4. `Architectural Editor`
   Own review of the runtime model, persistence boundary, and invariant
   discipline before implementation broadens.
5. `Studio Coverage Architect`
   Own deterministic validation for durable thread, speaker attribution, and
   activation-trace checkpoint behavior.

Keep these roles on deck rather than in the core first squad unless the build
reveals an immediate need:

- `Studio Reliability Engineer`
  Bring in when multi-participant coordination starts creating async or
  cancellation risk.
- `Studio Interaction Quality Lead`
  Bring in after the first checkpoint is real and interaction polish becomes a
  gating concern.
- `Taskboard Parity Designer`
  Not needed for the first Orbit proving checkpoint because this milestone is
  about structural clarity, not Trello-like parity work.

## Minimum Valid Rerun Participants

For the next fresh-worktree Orbit rerun, these roles are required:

1. `Samwise`
   Coordinator and facilitator only.
   Samwise owns scope, evidence discipline, and closeout synthesis.
2. `Senior SwiftUI Engineer`
   Required implementation agent.
3. `Venture Product Steward`
   Required product reviewer.
4. `Studio Interaction Quality Lead`
   Required interaction-quality reviewer.
5. `Studio Coverage Architect`
   Required validation and evidence reviewer.

Minimum valid rerun structure:

1. at least one persona-backed implementation sub-agent
2. at least two distinct non-implementation review passes
3. participant evidence captured for every active role used to justify the run
4. no planned role may be described as active participation unless an artifact
   exists for that role

## MVP Boundary

For Orbit execution, `MVP` means the first engineering checkpoint defined in
this document:

- Phase 1
- Phase 2
- minimal Phase 3

This MVP must produce a usable local Orbit command-center loop.

It does not require:

- Phase 4 summary and memory review
- Phase 5 memory reuse

Those belong to the first post-MVP extension unless AJ explicitly redefines the
milestone.

## Branch And Worktree Strategy

Use three branches/worktrees for this execution phase:

- `main`
  Protected. No autonomous commit authority.
- `codex/orbit-foundation`
  Approved non-`main` worktree for autonomous delivery of Phase 1, Phase 2,
  and minimal Phase 3.
- `codex/orbit-learning-loop`
  Approved non-`main` worktree branching from `codex/orbit-foundation` for
  speculative Phase 4 and Phase 5 work after the MVP loop is usable.

Rules:

1. `codex/orbit-foundation` is the official MVP branch.
2. `codex/orbit-learning-loop` is exploratory until AJ explicitly promotes it.
3. Worktree approval replaces per-commit approval only inside the named
   non-`main` worktrees.
4. `main` remains manual-review only.
5. Major scope or architecture changes outside this execution plan still pause
   for AJ review.

## Fresh-Main Rerun Branch Naming

The first Orbit exercise used named branches:

- `codex/orbit-foundation`
- `codex/orbit-learning-loop`

Future fresh-main Orbit reruns should use a simple incrementing integer in the
branch name:

- `codex/orbit-1`
- `codex/orbit-2`
- `codex/orbit-3`

Rules:

1. increment the integer for each new fresh-main Orbit attempt
2. do not reuse a previous attempt branch name
3. use the integer as the attempt number, not as a phase label
4. if a future attempt needs a paired exploratory lane, derive it from the
   attempt number instead of inventing a new naming pattern

This keeps branch naming simple, comparable, and easy to discuss across
attempts.

## Retrospective Requirement

Orbit milestones do not end at implementation or review alone.

Whenever a milestone, checkpoint, phase, sprint, or other approved work slice
ends, Orbit requires:

1. checkpoint review
2. retrospective closeout
3. one canonical Starfish retrospective report synthesized from multiple
   AI-assisted passes

Default cadence and synthesis rules live in:

- `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md`

Default closeout method:

1. `fan-out` first
2. short `roundtable` second
3. one canonical `Starfish` synthesis

Do not use a single-method closeout by default unless AJ explicitly narrows the
method for a smaller checkpoint.

## Required Review Gates Before MVP-Candidate Language

Do not use `review-ready`, `MVP candidate`, or similar milestone-complete
language until all of these are true:

1. the product acceptance checklist has been run:
   - `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
2. the interaction-quality review pass has been recorded
3. feature, product, process, and persona-fidelity confidence have been scoped
   separately in the closeout artifacts
4. the required hybrid retrospective closeout has completed

## Startup Artifacts For The Next Fresh Worktree

The next Orbit rerun should start from:

1. `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
2. `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`

These are not optional reference docs.
They are part of the execution contract for a repeatable rerun.

## RFC Guardrails For This Milestone

We do not need a full RFC review right now.

We do need selective reference checks while building:

### Review Now

- `RFC-0001`
  Use for activation expectations and persisted activation context.
- `RFC-0002`
  Use for workspace, conversation, meeting, and runtime-state boundaries.

### Review When Phase 4 Begins

- `RFC-0005`
  Use when summary, journaling, memory candidate review, and governance enter
  active implementation scope.

### Review Later

- `RFC-0003`
  Useful when workspace persona identity deepens beyond the first checkpoint.
- `RFC-0004`
  Useful when teams, squads, or richer meeting coordination move beyond the
  lightweight proving-loop model.
- `RFC-0006`
  Useful when multi-client and backend platform questions become active rather
  than speculative.

## Execution Risks To Watch

- building too much infrastructure before the first checkpoint is real
- letting meeting orchestration become heavier than the product surface needs
- treating activation trace as optional instead of foundational
- jumping into memory work before the workspace and conversation loop feel solid

## Recommended Next Artifact

The next planning artifact should be:

- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`

After that, the next follow-up artifact should be:

- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`

That sequence keeps the execution anchor concise while giving the first build a
clear data-model boundary before UI work expands.

## Revision Notes

- 2026-03-09: Initial Samwise execution-plan draft created from the approved
  proving-loop and command-center planning artifacts plus Meeting 002 closeout.
- 2026-03-09: Added a mandatory retrospective closeout rule for Orbit
  milestones and linked to the shared Orbit retrospective policy.
- 2026-03-09: Added proposed first-squad staffing guidance and promoted a
  dedicated first-checkpoint runtime-model note as the immediate next artifact.
- 2026-03-09: Defined the Orbit MVP boundary and named the milestone and
  exploratory worktree strategy for autonomous non-`main` execution.
- 2026-03-09: Added the first-checkpoint implementation-breakdown artifact as
  the next file/module planning step for `codex/orbit-foundation`.
