# Orbit First Checkpoint Implementation Breakdown

Status: Draft
Owner: Samwise
Workspace: Orbit
Last Updated: 2026-03-09

## Purpose

Map the first Orbit execution checkpoint into the existing PersonaKit Studio
codebase so implementation can start without drifting into broad platform
rewrites.

This breakdown is intentionally practical:

- use the current Studio app as the proving surface
- reuse existing workspace-loading seams where possible
- keep new Orbit runtime state local and deterministic
- avoid Phase 4 and Phase 5 work in this lane

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

## Build Direction

For the first checkpoint, Orbit should be implemented as a new Studio feature
surface inside the existing macOS app, not as a second app shell and not as a
rewrite of the current PersonaKit workspace model.

That means:

1. add one Orbit panel to the Studio sidebar flow
2. persist Orbit-local runtime data inside the selected workspace
3. keep PersonaKit workspace loading as the outer container
4. defer any deeper backend or multi-client architecture

## Proposed File And Module Breakdown

### 1. Orbit Runtime Models

Recommended new files:

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

Recommended new file:

- `Sources/Features/Studio/UI/Orbit/OrbitPanelView+Persistence.swift`

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

Recommended new files:

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

- how do Samwise and ProdDoc produce first-checkpoint responses without
  inventing a full execution engine?

Recommended first implementation approach:

1. persist participant records with stable PersonaKit identity references
2. keep response generation as a narrow bridge layer inside the Orbit feature
3. reuse existing session-preview/export plumbing where it helps expose:
   - persona identity
   - directive identity
   - activation trace context

This is the one area where a small spike may be required before the full
checkpoint can be declared implementation-ready.

## First Build Sequence

### Step 1

Create Orbit runtime models plus deterministic persistence.

Definition of done:

- the selected workspace can load or create a default Orbit runtime file
- the file round-trips cleanly through encode/decode

### Step 2

Add the Orbit panel to Studio navigation and render:

- workspace header
- founding-group roster
- empty or seeded thread state

Definition of done:

- Orbit is visibly present in the macOS app as a distinct workspace surface

### Step 3

Implement durable thread and message editing/submission behavior.

Definition of done:

- messages persist across app restart
- visible speaker attribution exists

### Step 4

Implement participant addressing and the minimal activation-record write path.

Definition of done:

- a response event can create an activation record with persona/directive
  attribution
- the UI can reveal lightweight trace data for a response

### Step 5

Run a checkpoint review before touching summaries or memory candidates.

Definition of done:

- the app satisfies the MVP boundary in `Orbit-Execution-Plan.md`

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

## Key Risk

The biggest implementation risk is not persistence or UI wiring.

It is the first response-generation seam for Samwise and ProdDoc.

If that seam grows too large, Orbit can drift into execution-engine work before
the local command-center loop is proven.

## Recommended Immediate Coding Start

The first code slice should be:

1. add Orbit runtime models
2. add deterministic persistence under `.personakit/Orbit/`
3. add an Orbit panel placeholder to the Studio sidebar

That slice gives us visible product progress without committing yet to the
heavier response-generation bridge.

## Revision Notes

- 2026-03-09: Initial Samwise file/module breakdown created for the Orbit MVP
  lane after bootstrapping `codex/orbit-foundation`.
- 2026-03-09: Completed the first Orbit implementation pass in Studio with
  runtime models, deterministic `.personakit/Orbit/` persistence, sidebar
  navigation, direct-address and founding-group response bridging, activation
  trace rendering, model tests, and Orbit snapshot baselines.
