# Orbit Retrospective Method Decision

- Date: 2026-03-09
- Objective: Decide which retrospective method Orbit should trust more after
  the first head-to-head comparison.
- Evidence Packet:
  - `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
- Reviewer:
  - `Samwise`

## Outcome

- Winning method: `Roundtable`, if Orbit must choose a single method
- Or hybrid decision: `Adopt a hybrid default: fan-out first, short roundtable second, one canonical Starfish at the end`

## Why

1. `Fan-Out` produced the cleanest persona separation and the fastest first-pass evidence generation.
2. `Roundtable` produced the sharpest final wording around product bugs, proof boundaries, and false credit inflation.
3. Orbit needs both clean persona boundaries and visible collaborative judgment, so the hybrid model matches the actual goal better than either method alone.

## Trust Judgment

Which method would AJ trust more for changing Orbit and the squad next?

1. AJ should trust the `hybrid` method most, because it preserves fan-out's clean raw passes and speed while using the roundtable to challenge, refine, and de-mush the final language before policy or plan changes are made.

## Product Finding Summary

1. The strongest product truth from both methods is that Orbit's current UI is reviewable but not yet intentional: neutral state is wrong, the primary CTA is unstable, inline help is compensating for unclear structure, and the panel needs stronger top-anchored composition discipline.

## Process Finding Summary

1. The strongest process truth from both methods is that the lane model worked, but the intended multiagent/persona experiment did not. Future Orbit runs need explicit participation requirements, named reviewer ownership, and evidence-backed closeout rules before broad process claims are earned.

## Persona Fidelity Summary

1. Fan-out best preserved one-persona-per-pass discipline, while roundtable best exposed how the personas reason together once the raw findings exist. That is why fan-out should lead and roundtable should follow.

## Decision

1. Keep as default: `Hybrid`
2. Use only in these situations:
   - `Fan-Out only` when time pressure is high and the goal is first-pass evidence gathering.
   - `Roundtable only` when a milestone is small and the cost of parallel fan-out is not justified.
   - `Hybrid` for milestone closeout, process evaluation, persona-fidelity review, or any checkpoint likely to change Orbit plans or squad rules.
3. Re-test after: the next full Orbit rerun that actually exercises explicit multiagent participation and design-review gates.

## Follow-Up Actions

1. Item: Revise Orbit execution and rerun-prep docs to require the hybrid retrospective flow for milestone closeout unless AJ explicitly selects another method.
   - Owner: Samwise
   - Checkpoint: before the next Orbit rerun begins
   - Success signal: active Orbit planning and execution docs name the hybrid retrospective as the default closeout path
2. Item: Add a frozen evidence manifest section and scoped confidence ledger to the next retrospective packet.
   - Owner: Studio Coverage Architect + Samwise
   - Checkpoint: before the next Orbit retrospective starts
   - Success signal: next packet distinguishes feature, product, and process confidence with explicit evidence references
3. Item: Turn the product and interaction findings from this comparison into concrete Orbit acceptance criteria for the next implementation slice.
   - Owner: Venture Product Steward + Studio Interaction Quality Lead + Senior SwiftUI Engineer
   - Checkpoint: before the next Orbit UI implementation pass starts
   - Success signal: revised Orbit checkpoint docs include neutral-state, stable-CTA, top-alignment, and no-inline-help expectations
