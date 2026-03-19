# Orbit Attempt 1 Retrospective

Status: Accepted
Owner: `samwise`
Date: 2026-03-18
Artifact Pattern: `2026-03-10-orbit-1`
Current Lane: `codex/orbit-m0`

## Outcome Split

- feature outcome: local Orbit room is now reviewable across first-open,
  durability, routing, and trace proof
- product outcome: Orbit reads more like a command center than chat, with a few
  intentional checkpoint limits still visible
- process outcome: execution evidence and review-owner artifacts are much
  stronger than the original foundation run
- persona-fidelity outcome: better than the first Orbit pass, but still not a
  full long-lived multiagent execution model

## Canonical Starfish

### Keep Doing

1. Keep tying implementation slices to explicit milestone packets and proof notes.
2. Keep using deterministic persistence and snapshot proof as part of product
   review, not only engineering validation.

### Less Of

1. Less always-open metadata in the room surface when a lighter disclosure can do
   the same explainability work.
2. Less hidden default intent in composer state.

### More Of

1. More direct routing explanation from the room surface itself.
2. More attempt-specific evidence written while the work is fresh, not only at
   the end.

### Stop Doing

1. Stop letting checkpoint closeout depend on implied reviewer participation.
2. Stop treating a technically working room as sufficient without product-surface
   proof.

### Start Doing

1. Start packaging packet-specific re-proof notes as soon as a checkpoint slice
   lands.
2. Start carrying direct product and interaction review language into the closeout
   packet earlier in the milestone.

## Action Items

1. Item: Keep `M2` review focused on the room surface rather than reopening `M3`
   concerns.
   - Owner: `samwise`
   - Checkpoint: before AJ `M2` review begins
   - Success signal: review packet speaks only to the local command-center loop
2. Item: Split large Orbit model logic before the room grows materially beyond the
   checkpoint.
   - Owner: `senior-swiftui-engineer`
   - Checkpoint: before major post-`M2` Orbit surface expansion
   - Success signal: `OrbitModels.swift` stops accumulating unrelated concerns

## Judgment

This attempt is materially healthier than the original Orbit foundation run.

The room is now defended by real proof, not just a functional demo surface.

Current disposition:

- this retrospective is part of the accepted `M2` closeout packet
