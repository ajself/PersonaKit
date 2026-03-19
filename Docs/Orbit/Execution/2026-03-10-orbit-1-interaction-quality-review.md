# Orbit Attempt 1 Interaction Quality Review

Status: Draft
Owner: `studio-interaction-quality-lead`
Grounding: `studio-interaction-quality-lead` + `apply-style`
Date: 2026-03-18
Artifact Pattern: `2026-03-10-orbit-1`
Current Lane: `codex/orbit-m0`

## Decision

- result: `pass with notes`

## Review Readout

### Layout and stability

- pass: panel composition stays top-anchored across first-open, empty, direct,
  and meeting states
- pass: the workspace header now does real orienting work instead of reading like
  generic chrome

### Roster and state legibility

- pass: roster state is visible without becoming noisy
- pass: explicit address and recent activity are differentiated cleanly
- pass: no collaborator starts falsely highlighted by default

### Conversation and routing clarity

- pass: direct-address and lightweight-meeting routing are both legible from the
  room surface
- pass: the composer explains the current routing mode before send
- note: the current-thread steward path is readable, but remains intentionally
  lighter than a full room-orchestration model

### Trace weight

- pass: trace is product-visible rather than debug-only
- pass: disclosure-based trace is lighter than the always-open `M1` trace block
- note: expanded trace content still adds noticeable vertical weight, which is
  acceptable for the checkpoint but should be watched in later UI work

## Strongest Interaction Improvements

1. Stable action language avoids mode-switch confusion.
2. Routing explainer copy makes direct and group exchange feel intentional.
3. Trace disclosure is discoverable without dominating first-open composition.

## Biggest Remaining Interaction Notes

1. Expanded trace panels can still make the room feel denser during inspection.
2. The room still has a checkpoint-density feel rather than a fully relaxed,
   mature command-center rhythm.

## Evidence Used

1. `Docs/Orbit/Planning/Milestones/M2-Single-Workspace-macOS-Command-Center/Command-Center-Experience-Bar.md`
2. `Docs/Orbit/Planning/Milestones/M2-Single-Workspace-macOS-Command-Center/Command-Center-Shell-Reproof-Note.md`
3. `Docs/Orbit/Planning/Milestones/M2-Single-Workspace-macOS-Command-Center/Addressing-And-Lightweight-Exchange-Reproof-Note.md`
4. `Docs/Orbit/Planning/Milestones/M2-Single-Workspace-macOS-Command-Center/Activation-Trace-Visibility-Reproof-Note.md`
5. `Tests/Features/Studio/__Snapshots__/OrbitSnapshotTests/testOrbitDefaultWorkspace.orbit-default-workspace.png`
6. `Tests/Features/Studio/__Snapshots__/OrbitSnapshotTests/testOrbitDirectAddressTraceExpanded.orbit-direct-address-trace-expanded.png`
7. `Tests/Features/Studio/__Snapshots__/OrbitSnapshotTests/testOrbitEmptyWorkspace.orbit-empty-workspace.png`

## Judgment

The current command-center surface is interaction-reviewable and clears the
checkpoint bar with notes.
