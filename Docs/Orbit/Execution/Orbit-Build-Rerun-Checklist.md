# Orbit Build Rerun Checklist

Status: Draft
Owner: Samwise
Last Updated: 2026-03-09

## Purpose

Provide the startup and closeout checklist for a fresh `main`-based Orbit
worktree rerun.

Use this checklist before coding begins.

This is the operator playbook for rerunning the `Build Orbit` exercise at a
comparison-grade standard.

If invoking the rerun through PersonaKit, start from:

- `samwise-orbit-build-rerun`

## Startup Sequence

Complete these steps in order.

### 0. Choose the next integer branch name

For fresh Orbit reruns from `main`, use a simple incrementing branch name:

1. `codex/orbit-1`
2. `codex/orbit-2`
3. `codex/orbit-3`

Rule:

1. increment the integer for each new fresh-main Orbit attempt
2. do not reuse an earlier Orbit attempt branch name
3. treat the integer as the attempt number, not as a product phase label

Historical note:

- `codex/orbit-foundation` remains the original named foundation lane from the
  first Orbit exercise
- future fresh-main reruns should use the integer pattern instead

### 1. Verify `main` readiness

Confirm that local `main` already contains:

1. worktree lane tooling
2. retrospective contract and schema changes
3. the active Orbit planning and execution docs that define the rerun

Do not create the fresh worktree until those prerequisites are present.

### 2. Create and bootstrap the approved lane

1. create the approved Orbit worktree from `main`
   - use the next integer branch name, for example `codex/orbit-2`
2. enter the new worktree
3. run:
   - `Scripts/bootstrap-worktree-lane.sh`
   - `Scripts/check-worktree-lane.sh`

### 3. Run baseline validation before coding

Run:

1. `swift run personakit validate --root .personakit`
2. `./Scripts/check-worktree-squad-logs.sh`

If baseline validation is not green, do not start the rerun.

### 4. Confirm the required active participants

Record the expected active roles for the rerun:

1. `Samwise`
   coordinator/facilitator only
2. `Senior SwiftUI Engineer`
   required implementation agent
3. `Venture Product Steward`
   required product reviewer
4. `Studio Interaction Quality Lead`
   required interaction-quality reviewer
5. `Studio Coverage Architect`
   required validation/evidence reviewer

Minimum valid rerun structure:

1. at least one persona-backed implementation sub-agent
2. at least two distinct non-implementation review passes
3. participant evidence captured for each active role

Planned roles do not count as active participation.

### 5. Freeze evidence expectations before implementation

Before the first code slice begins, record what artifacts the rerun must
produce:

1. implementation evidence
2. product acceptance checklist result
3. interaction-quality review artifact
4. validation/evidence closeout artifact
5. participant evidence for all active roles
6. hybrid retrospective artifacts
7. red-pen evidence for each active owner's deliverable

### 6. Carry forward the last attempt's lessons explicitly

Before the first code slice begins, load:

1. the latest rerun-prep note
2. the latest canonical Orbit retrospective
3. the latest evidence packet
4. the latest retrospective comparison decision when method choice is relevant

Summarize what must be kept, corrected, or re-tested in the current attempt.

## First Slice Rule

The first implementation slice is still:

1. Orbit runtime models
2. deterministic persistence
3. Studio Orbit surface shell

Do not broaden into later Orbit phases before this checkpoint is proven again.

## Required Review Gates

Before describing the branch as `review-ready` or `MVP candidate`, complete all
of these:

1. each active owner has run at least three red-pen passes on their deliverable
   and recorded the resulting changes or "no further material issues found"
2. run the product acceptance checklist:
   - `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. record the interaction-quality review pass
4. record validation findings with separate:
   - feature confidence
   - product confidence
   - process confidence
   - persona-fidelity confidence
5. run hybrid retrospective closeout:
   - `fan-out` first
   - short `roundtable` second
   - one canonical `Starfish` synthesis

Minimum red-pen expectation per owner:

1. pass 1
   structural and scope red-pen
2. pass 2
   correctness, bug risk, and edge-case red-pen
3. pass 3
   clarity, UX/product fit, or maintainability red-pen

If external review causes material changes, run one fresh red-pen pass before
re-submitting the deliverable.

## Promotion Safety Check

Before any promotion or rebase decision back toward `main`, confirm that the
milestone closeout artifacts exist:

1. checkpoint review
2. product acceptance checklist
3. interaction-quality review artifact
4. validation/evidence closeout artifact
5. hybrid retrospective closeout artifacts
6. one canonical closeout summary that distinguishes:
   - feature outcome
   - product outcome
   - process outcome
   - persona-fidelity outcome

## Ready To Start From `main`

Orbit is ready for a fresh `main`-based worktree only when all are true:

1. `main` contains the lane tooling and retrospective contract changes from
   this branch
2. Orbit execution docs name the required participants and review gates
   explicitly
3. this rerun checklist exists and is current
4. the product acceptance checklist exists and is current
5. hybrid retrospective closeout is the stated default
6. a fresh reader can determine success criteria without consulting thread
   history
