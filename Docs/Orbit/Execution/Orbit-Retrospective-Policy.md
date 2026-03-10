# Orbit Retrospective Policy

Status: Draft
Owner: Samwise
Last Updated: 2026-03-09

## Purpose

Define when Orbit retrospectives are required, how many AI-assisted passes
should run, and how multiple passes should be synthesized into one canonical
Orbit retrospective.

For a head-to-head comparison of retrospective methods, see:

- `Docs/Orbit/Execution/Orbit-Retrospective-Methodology-Comparison.md`

## Required Trigger

An Orbit retrospective is required whenever one of these boundaries is reached:

1. a named milestone or checkpoint completes
2. a phase completes
3. an approved sprint or timebox ends
4. a lane pauses because the planned work slice is complete
5. a lane pauses because review feedback or process concerns make continuation
   unsafe or misleading

The retrospective is part of the milestone closeout.

A milestone should not be treated as fully closed until:

1. review has happened
2. a retrospective has been run
3. the retrospective output has been reduced into one canonical Starfish report

## Default Format

Orbit retrospectives should use the Starfish format by default:

- `Keep Doing`
- `Less Of`
- `More Of`
- `Stop Doing`
- `Start Doing`

This format is preferred because Orbit retrospectives usually need to judge
both:

- product quality
- process quality

## Default Method

The first Orbit retrospective-method comparison is complete.

Default Orbit closeout method:

1. `fan-out` first
2. short `roundtable` second
3. one canonical `Starfish` synthesis at the end

Use this hybrid method by default for milestone closeout unless AJ explicitly
selects a different method.

Reason:

1. `fan-out` preserves the cleanest persona separation and first-pass evidence
2. `roundtable` sharpens disagreement handling, product language, and final
   action framing
3. Orbit needs both

## AI Pass Count

Because Orbit work often mixes product, code, persona, and process evaluation,
the retrospective should be run more than once before the canonical report is
written.

Recommended range:

- minimum: `3` passes
- maximum: `5` passes

### Minimum Three Passes

1. `Delivery pass`
   Evidence-first summary of what shipped, what validated, and what failed.
2. `Product/design pass`
   Focus on layout, clarity, interaction quality, and whether the feature feels
   like Orbit rather than generic chat.
3. `Process/persona pass`
   Focus on squad behavior, persona fidelity, delegation evidence, stop-point
   discipline, and whether the run actually matched the intended operating
   model.

### Optional Additional Passes

4. `Architecture/quality pass`
   Use when runtime boundaries, invariants, or validation quality are in doubt.
5. `Gardening/synthesis pass`
   Use when Rosie or another reviewer should mine the earlier passes for
   repeated patterns and next-iteration recommendations.

## How To Synthesize Multiple Passes

The final output should be one canonical Starfish retrospective, not a pile of
competing summaries.

Use this synthesis rule:

1. Gather all candidate findings from every pass.
2. Merge duplicates that are clearly the same issue or strength.
3. Promote an item into the canonical Starfish only when:
   - it appears in two or more passes
   - or it appears in one pass with direct evidence strong enough to stand on
     its own
4. If passes disagree:
   - keep the stronger evidence-backed phrasing
   - note the disagreement in the evidence section or narrative summary
   - do not average contradictory claims into vague language
5. Convert every `Start Doing` or `Stop Doing` item that matters for the next
   run into an explicit action item with owner and checkpoint.

## Interpretation Guidance

Use the Starfish buckets this way:

- `Keep Doing`
  Evidence-backed strengths that should remain part of the Orbit loop.
- `Less Of`
  Behaviors that were not fully wrong but were overused or overemphasized.
- `More Of`
  Behaviors that helped and need stronger presence next time.
- `Stop Doing`
  Behaviors that actively distorted product quality, process quality, or
  persona fidelity.
- `Start Doing`
  New rules, checks, or rituals needed before the next run.

## Orbit-Specific Rule

For Orbit, the retrospective must explicitly separate:

1. feature outcome
2. product outcome
3. process outcome
4. persona fidelity outcome

Without that split, it is too easy to confuse:

- a strong solo build
- a reviewable but still underdesigned product surface
- with a successful multiagent or persona-bound execution experiment

## Suggested Closeout Shape

The closeout packet for a milestone should ideally include:

1. checkpoint review
2. completed product acceptance checklist:
   - `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`
3. interaction-quality review artifact
4. canonical Starfish retrospective
5. action-item list with owners and checkpoints
6. any supporting participant notes or pass-specific appendices

For the next fresh worktree, startup should begin from:

- `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`

## Revision Notes

- 2026-03-09: Added the first Orbit retrospective policy to require milestone
  closeout retrospectives and define multi-pass Starfish synthesis.
- 2026-03-09: Recorded the first method-comparison result and adopted `hybrid`
  as the default Orbit retrospective closeout path.
