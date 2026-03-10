# Orbit Foundation Rerun Prep

Status: Historical carry-forward context
Owner: Samwise
Date: 2026-03-09
Related Branch: `codex/orbit-foundation`
Related Retrospective: `2026-03-09-orbit-foundation-retrospective.md`

## Purpose

Preserve the notes that existed before AJ's code review and product review
turned into plan revisions and a second attempt at the Orbit execution
exercise.

This note is intentionally preparation-focused.
It is preserved as first-attempt carry-forward input, not as the active startup
surface for the next rerun.

It assumes:

- a code review is still coming
- a product review is still coming
- plan and process revisions will happen after those reviews
- the multiagent execution exercise will be attempted again in a corrected form

## Core Correction

The next run should not be framed as:

- "continue building Orbit"

It should be framed as:

- "rerun the Orbit execution experiment with corrected process expectations"

That means the next pass has two simultaneous goals:

1. continue or refine the Orbit product itself
2. correctly exercise the collaboration model that this first run only partially
   tested

## Retrospective Default For The Rerun

The retrospective-method comparison is now complete.

For the next Orbit rerun, milestone closeout should default to:

1. `fan-out` first
2. short `roundtable` second
3. one canonical `Starfish` synthesis

Do not fall back to a single-method retrospective unless AJ explicitly chooses
to do so for a smaller checkpoint.

Startup for the next fresh worktree should begin from:

- `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`

Required product review artifact:

- `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`

## Explicit Expectations For The Next Attempt

The following expectations were visible in the planning and discussion leading
up to the first run and should be made explicit in the revised plan before the
next attempt begins:

1. Multiple personas are not optional context. They are active execution
   participants.
2. Persona-backed sub-agents must be part of the run if the run is being used
   to evaluate the multiagent model.
3. Orbit UI work must include an intentional "refined but still in progress"
   product-review posture.
4. Start-of-run confidence should be high and justified, not merely hopeful.
5. The squad leader must run a participant-based retrospective, not just write
   an after-action memo alone.
6. Milestone closeout must require a multi-pass retrospective process, not a
   single retrospective draft.
7. The default multi-pass closeout method is now `hybrid`, not an unstructured
   collection of retrospective notes.
8. Each active owner should red-pen their own deliverable at least three times
   before the checkpoint is described as done.

## Questions To Resolve During Code Review

These are the most useful code-review questions for the upcoming review:

1. Is the Orbit runtime model appropriately minimal for the MVP, or did it
   hard-code too much first-pass behavior?
2. Is the deterministic participant response bridge acceptable as a checkpoint
   placeholder, or does it distort the real Orbit interaction model too much?
3. Is `.personakit/Orbit/orbit-workspace.json` the right persistence boundary
   for this checkpoint?
4. Did the Taskboard unblock-only cleanup stay acceptably bounded, or should
   some of it be separated conceptually from Orbit work?
5. Are the Orbit tests meaningful enough to support iteration, or do they only
   prove a narrow happy path?

## Questions To Resolve During Product Review

These are the most useful product-review questions for the upcoming review:

1. Does the Orbit panel feel structurally different from generic chat?
2. Does the roster feel like persistent collaborators rather than labels?
3. Is the lightweight meeting invitation understandable and worth keeping in
   the current form?
4. Does the activation trace feel appropriately lightweight, or too mechanical,
   too hidden, or too prominent?
5. What is the smallest visual/product refinement set needed before the
   checkpoint should be considered a true MVP review candidate?

## Plan Revisions Likely Needed After Review

These are the files most likely to need revision once the reviews are complete:

1. `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
2. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`
3. `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
4. `Docs/PersonaKit/Development/worktree-squad-cheat-sheet.md`
5. Any worktree-squad retrospective or loop contracts that should better
   enforce participant-based retrospectives and required delegation
6. `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md`
7. `Docs/Orbit/Execution/Orbit-Retrospective-Methodology-Comparison.md`
8. `Docs/Orbit/Execution/Orbit-Build-Rerun-Checklist.md`
9. `Docs/Orbit/Execution/Orbit-Product-Acceptance-Checklist.md`

## Support-File Revisions Likely Needed

The first run suggests several support files may need tightening after the
reviews:

1. lane or squad docs should specify minimum active persona/sub-agent counts
   when a run is intended as a multiagent experiment
2. retrospective docs should distinguish:
   - single-author reflection
   - participant roundtable retrospective
3. review docs should distinguish:
   - functional checkpoint readiness
   - design-review readiness
   - process-experiment readiness
4. confidence handling should distinguish:
   - confidence in the product slice
   - confidence in the process model
5. Orbit docs should state how many AI-assisted retrospective passes must run
   before a canonical report is accepted
6. Orbit docs should make the hybrid closeout default explicit in active
   execution notes and rerun expectations

## Recommended Evidence Requirements For The Next Attempt

If the next attempt is meant to validate the process more honestly, it should
collect explicit evidence for:

1. which personas were active
2. which sub-agents were spawned
3. which files or scopes each worker owned
4. what design/product review occurred
5. what validation owner concluded
6. what each participant contributed to the retrospective
7. how the multiple retrospective passes were synthesized into one final
   Starfish report
8. whether the hybrid closeout flow actually ran as required
9. whether the resulting retrospective still justifies keeping hybrid as the
   default closeout method

Without those artifacts, it will be too easy to confuse a strong solo run with
a successful multiagent run again.

## Minimum Success Criteria For The Rerun

The next attempt should not be called successful as a multiagent exercise unless
it achieves all of the following:

1. At least one persona-backed implementation sub-agent contributes materially.
2. At least one separate reviewer persona contributes materially.
3. The UI/UX receives an explicit in-progress product/design review.
4. The squad leader coordinates a retrospective with multiple participant
   viewpoints.
5. The final retrospective distinguishes clearly between:
   - product outcome
   - process outcome
6. The final retrospective is the canonical Starfish synthesis of multiple
   evidence-backed passes rather than a single unchallenged draft.
7. The rerun closes with the agreed hybrid retrospective flow unless AJ
   explicitly narrows the method for that checkpoint.
8. The rerun produces enough retrospective evidence to confirm or revise the
   current hybrid default honestly.

## Immediate Note For Future Samwise Re-entry

When resuming after AJ's code and product review:

1. Start by re-reading:
   - `2026-03-09-orbit-foundation-retrospective.md`
   - this rerun-prep note
   - the active Orbit planning docs
2. Treat AJ's review feedback as input to both:
   - Orbit product revisions
   - multiagent process revisions
3. Do not start the rerun until the revised expectations are written into the
   active plan or support docs clearly enough that the next run can be judged
   against them.
