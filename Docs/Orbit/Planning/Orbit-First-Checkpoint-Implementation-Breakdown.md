# Orbit First Checkpoint Implementation Breakdown

Status: Accepted
Owner: Samwise
Workspace: Orbit
Last Updated: 2026-03-18

## Purpose

Map the first Orbit execution checkpoint into the existing PersonaKit Studio
codebase so implementation can start without drifting into broad platform
rewrites.

This breakdown is intentionally practical:

- use the current Studio app as the proving surface
- reuse existing workspace-loading seams where possible
- keep new Orbit runtime state local and deterministic
- avoid Phase 4 and Phase 5 work in this lane

Accepted here means this file is the approved codebase-facing map for first-
checkpoint reruns and implementation planning. It does not mean every listed
file or proof obligation is already in an acceptable finished state.

## Current Role In The Planning Stack

This file is the codebase-facing implementation map for the first checkpoint.

It should be used when planning or replaying `M2` work in a fresh-main Orbit
lane.

It should not be treated as the long-term Orbit platform architecture plan.
That broader shift begins at `M3` in
`Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`.

## Current Codebase Anchors

The best existing seams for the Orbit MVP are:

1. App entry:
   - `Sources/App/Studio/PersonaKitStudioApp.swift`
2. Root navigation and panel switching:
   - `Sources/Features/Studio/UI/StudioRootView.swift`
3. Workspace-level state owner:
   - `Sources/Features/Studio/Presentation/Store/WorkspaceStore.swift`
4. Workspace operation coordination:
   - `Sources/Features/Studio/Foundation/WorkspaceOperationRunner.swift`
5. Existing local persisted feature precedent:
   - `Sources/Features/Studio/UI/Taskboard/TaskboardPanelView+Persistence.swift`
6. Existing session-preview bridge into PersonaKit resolution/export:
   - `Sources/Features/Studio/Foundation/WorkspaceSessionPreviewManager.swift`

Current first-checkpoint Orbit files already present in the repo:

- `Sources/Features/Studio/UI/Orbit/OrbitModels.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitSampleData.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+UI.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+Persistence.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitParticipantResponseBridge.swift`

Current first-checkpoint validation artifacts already present in the repo:

- `Tests/Features/Studio/OrbitWorkspaceTests.swift`
- `Tests/Features/Studio/OrbitSnapshotTests.swift`

## Build Direction

For the first checkpoint, Orbit should be implemented as a new Studio feature
surface inside the existing macOS app, not as a second app shell and not as a
rewrite of the current PersonaKit workspace model.

That remains true even though a first implementation pass now exists in the
repo. Fresh-main reruns should treat the existing Orbit files as comparison
evidence and refinement targets, not as permission to broaden scope.

That means:

1. add one Orbit panel to the Studio sidebar flow
2. persist Orbit-local runtime data inside the selected workspace
3. keep PersonaKit workspace loading as the outer container
4. defer any deeper backend or multi-client architecture

## Proposed File And Module Breakdown

### 1. Orbit Runtime Models

Current or target files:

- `Sources/Features/Studio/UI/Orbit/OrbitModels.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitSampleData.swift`

Responsibility:

- define the first-checkpoint entities:
  - workspace
  - participant
  - conversation thread
  - message
  - activation record
- keep them `Codable`, deterministic, and local-first
- provide normalized sample/default Orbit workspace data for first load

Why here:

- the first checkpoint is still a Studio-local proving surface
- taskboard already demonstrates a feature-local persisted model pattern

### 2. Orbit Persistence

Current or target file:

- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+Persistence.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitWorkspacePersistence.swift`

Responsibility:

- load and save Orbit runtime state under the selected workspace
- use deterministic JSON encoding:
  - pretty printed
  - sorted keys
- create the smallest local on-disk boundary for the checkpoint

Recommended workspace-local storage path:

- `.personakit/Orbit/orbit-workspace.json`

Optional split only if needed:

- `.personakit/Orbit/orbit-activation-records.json`

The default should stay one file until size or complexity forces a split.

### 3. Orbit Panel UI

Current or target files:

- `Sources/Features/Studio/UI/Orbit/OrbitPanelView.swift`
- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+UI.swift`

Responsibility:

- render workspace context
- render founding-group roster
- render the active conversation thread
- render lightweight activation trace visibility
- provide message entry and participant addressing controls

The panel should prove the product shape described in:

- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`

### 4. Studio Navigation Hookup

Primary files to update:

- `Sources/Features/Studio/UI/StudioRootView.swift`

Responsibility:

- add an Orbit sidebar destination
- route the detail view to the Orbit panel
- preserve the current PersonaKit Studio surfaces alongside Orbit

Recommendation:

- do not replace the whole Studio root yet
- add Orbit as one explicit proving surface while the checkpoint is maturing

### 5. Workspace Store Integration

Primary files to update:

- `Sources/Features/Studio/Presentation/Store/WorkspaceStore.swift`

Optional follow-on files only if needed:

- `Sources/Features/Studio/Presentation/Store/WorkspaceStore+OrbitActions.swift`

Responsibility:

- expose only the minimum shared state Orbit needs from the current workspace:
  - selected workspace URL
  - workspace load status
  - any future preview bridge hooks

Recommendation:

- keep Orbit runtime state owned by the Orbit feature first
- avoid pushing Orbit-specific message and activation state into
  `WorkspaceSnapshot` or `ContextWorkspaceCore` during this checkpoint

### 6. Participant Response Bridge

Primary existing seam:

- `Sources/Features/Studio/Foundation/WorkspaceSessionPreviewManager.swift`

Primary question:

- how do Samwise and ProdDoc as visible collaborators, with `ProdDoc` mapped to
  `venture-product-steward`, produce first-checkpoint responses without
  inventing a full execution engine?

Recommended first implementation approach:

1. persist participant records with stable PersonaKit identity references
2. keep response generation as a narrow bridge layer inside the Orbit feature
3. reuse existing session-preview/export plumbing where it helps expose:
   - persona-template identity
   - workspace persona identity anchor
   - directive identity
   - activation trace context

This is the one area where a small spike may be required before the full
checkpoint can be declared implementation-ready.

## First Build Or Rerun Sequence

### Step 1

Create or re-prove Orbit runtime models plus deterministic persistence.

Definition of done:

- the selected workspace can load or create a default Orbit runtime file
- the file round-trips cleanly through encode/decode

### Step 2

Add or re-prove the Orbit panel in Studio navigation and render:

- workspace header
- founding-group roster
- empty or seeded thread state

Definition of done:

- Orbit is visibly present in the macOS app as a distinct workspace surface

### Step 3

Implement or re-prove durable thread and message editing/submission behavior.

Definition of done:

- messages persist across app restart
- visible speaker attribution exists

### Step 4

Implement or re-prove participant addressing and the minimal activation-record
write path plus contract-snapshot persistence.

Definition of done:

- a response event can create an activation record with persona/directive
  attribution
- the same response path persists an inspectable contract snapshot, even when the
  first-checkpoint answer is an explicit empty set
- blocked identity or directive cases persist an activation-failure record plus a
  visible blocked system event instead of a fake collaborator reply
- persistence failure blocks the whole turn before new durable thread state is
  committed
- the UI can reveal lightweight trace data for a response

### Step 5

Run a checkpoint review and retrospective closeout before touching summaries or
memory candidates.

Definition of done:

- the app satisfies the MVP boundary in `Orbit-Execution-Plan.md`
- the milestone closeout retrospective required by
  `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md` has been run

## Required Rerun Operating Structure

For a fresh `main`-based Orbit rerun, implementation is not valid unless these
roles actually participate:

1. `Samwise`
   coordinator/facilitator only
2. `Senior SwiftUI Engineer`
   implementation owner
3. `Venture Product Steward`
   product review owner
4. `Studio Interaction Quality Lead`
   interaction-quality review owner
5. `Studio Coverage Architect`
   validation and evidence owner

Minimum valid rerun structure:

1. at least one persona-backed implementation sub-agent
2. at least two distinct non-implementation review passes
3. participant evidence captured for every active role

Planned roles do not count as active contributors.

## Required Review Artifacts

Before this checkpoint can be described as `review-ready` or `MVP candidate`,
the rerun must produce:

1. the startup and execution artifact:
   - `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
2. the product review artifact:
   - `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. an interaction-quality review pass
4. a validation/evidence closeout that distinguishes:
   - feature confidence
   - product confidence
   - process confidence
   - persona-fidelity confidence
5. the required hybrid retrospective closeout defined in
   `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md`

## Operator Startup Rule

When starting a fresh Orbit worktree from `main`, do not begin by reading only
this implementation breakdown.

Start in this order:

1. `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
2. `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. `Docs/Orbit/Execution/2026-03-10-orbit-1-rerun-prep.md`
4. `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
5. `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
6. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
7. this implementation breakdown

That keeps startup decisions anchored in the current rerun contract rather than
in thread history or older branch-specific notes.

## Explicit Deferrals

Do not include these in the current lane:

- summary generation
- memory candidate review
- memory reuse
- cross-workspace sharing
- deep team or squad modeling
- multi-client sync
- heavy analytics or orchestration UI

## Validation Expectations

Before the checkpoint is presented as usable, we should have:

1. deterministic local persistence checks for Orbit runtime files
2. manual restart verification for thread durability
3. verification that activation records render with visible attribution
4. review against the Orbit MVP boundary and command-center shape docs
5. product acceptance checklist completed
6. interaction-quality review artifact recorded
7. hybrid retrospective closeout completed

## Key Risk

The biggest implementation risk is not persistence or UI wiring.

It is the first response-generation seam for Samwise and ProdDoc, with
`ProdDoc` acting as the product-facing alias for `venture-product-steward`.

If that seam grows too large, Orbit can drift into execution-engine work before
the local command-center loop is proven.

## Recommended Immediate Coding Start

If starting a fresh-main rerun tomorrow, the first coding slice should be:

1. add Orbit runtime models
2. add deterministic persistence under `.personakit/Orbit/`
3. add an Orbit panel placeholder to the Studio sidebar

If working from the current repo instead of a fresh-main rerun, start by
red-penning and re-verifying the existing Orbit model, persistence, panel, and
response-bridge files against the current rerun contract before broadening the
surface.

## Revision Notes

- 2026-03-09: Initial Samwise file/module breakdown created for the Orbit MVP
  lane after bootstrapping `codex/orbit-foundation`.
- 2026-03-09: Completed the first Orbit implementation pass in Studio with
  runtime models, deterministic `.personakit/Orbit/` persistence, sidebar
  navigation, direct-address and founding-group response bridging, activation
  trace rendering, model tests, and Orbit snapshot baselines.
- 2026-03-09: Clarified that first-checkpoint closeout requires both review and
  retrospective before later phases begin.
- 2026-03-18: Updated this file to reflect that first-checkpoint Orbit files and
  tests already exist in the repo, clarified its role as the `M2` codebase map,
  and aligned fresh-main startup order with the roadmap, execution plan, and
  runtime-model note.
