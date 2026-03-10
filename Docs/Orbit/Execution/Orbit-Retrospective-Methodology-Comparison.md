# Orbit Retrospective Methodology Comparison

Status: Draft
Owner: Samwise
Last Updated: 2026-03-09

## Purpose

Define a head-to-head experiment for comparing two Orbit retrospective methods:

1. `Roundtable`
   A persona-labeled retrospective run in turns with visible participant
   responses and synthesis.
2. `Fan-Out`
   A parallel persona-labeled retrospective run where multiple passes execute
   concurrently and are synthesized afterward.

The goal is not just to choose the faster method.

The goal is to determine which method better serves Orbit's real needs:

- product-quality judgment
- process-quality judgment
- persona-fidelity judgment
- memory-ready retrospective output

## Shared Preconditions

Both methods must start from the same evidence packet.

The packet should include:

1. current Orbit retrospective draft
2. rerun-prep note
3. current code-review findings
4. current product-review findings
5. screenshots or recordings used in review
6. validation evidence
7. relevant active planning docs

Both methods must also follow these rules:

1. one active persona per agent at a time
2. evidence-linked findings only
3. Starfish output required
4. clear distinction between:
   - feature outcome
   - process outcome
   - persona fidelity outcome

## Experiment Controls

These controls are required if the comparison is supposed to be trustworthy.

1. `Frozen input`
   Both methods must use the exact same evidence packet.
2. `No cross-contamination`
   No participant in one method should see the other method's participant
   outputs or canonical synthesis until both methods are complete.
3. `Raw artifacts preserved`
   Each participant output must be saved before synthesis.
4. `Same judge`
   The same reviewer or scoring body should score both methods.
5. `Same output contract`
   Each participant contribution should answer the same Starfish prompt shape.

## Method A: Roundtable

### Shape

The roundtable runs in visible turns.

Suggested participants:

1. `Samwise`
   Facilitator and synthesis owner
2. `Senior SwiftUI Engineer`
   Delivery/code quality pass
3. `Venture Product Steward`
   Product-value and scope pass
4. `Studio Interaction Quality Lead`
   UI/UX and interaction-quality pass
5. `Studio Coverage Architect`
   validation and evidence pass

Optional:

- `Architectural Editor`
- `Rosie` after the main retrospective closes

Samwise should not open the roundtable with substantive Starfish findings.
That would anchor the room too early.

Samwise's roundtable role should be:

- frame the evidence packet
- enforce turn discipline
- ask for clarification when findings conflict
- synthesize only after the specialist turns are complete

### Flow

1. Samwise opens with the shared evidence packet and the retrospective goal.
2. Each participant responds in turn using the Starfish buckets.
3. Participants may react to earlier turns, refine disagreements, and sharpen
   language before synthesis.
4. Samwise produces the canonical Starfish report after the specialist turns
   are complete.

### Strengths To Test

- richer visible disagreement handling
- explicit participant interaction
- stronger sense of team process
- easier to inspect persona fidelity in context

### Risks To Test

- slower total turnaround
- late-turn anchoring bias
- stronger influence from facilitator wording
- more chance that later voices are shaped by earlier ones

## Method B: Fan-Out

### Shape

The fan-out runs the persona passes concurrently, then synthesizes once all
passes are complete.

Suggested parallel passes:

1. `Senior SwiftUI Engineer`
   Delivery/code quality pass
2. `Venture Product Steward`
   Product-value and scope pass
3. `Studio Interaction Quality Lead`
   UI/UX and interaction-quality pass
4. `Studio Coverage Architect`
   validation and evidence pass

Samwise does not blend into the passes.
Samwise synthesizes after all pass artifacts are complete.

### Flow

1. Freeze the shared evidence packet.
2. Give each participant the same prompt contract and the same Starfish output
   structure.
3. Run the participant passes in parallel.
4. Collect each pass as its own artifact.
5. Samwise synthesizes the canonical Starfish report from those artifacts.

### Strengths To Test

- lower wall-clock time
- less cross-participant anchoring
- cleaner persona separation
- easier side-by-side comparison of raw participant output

### Risks To Test

- weaker direct participant challenge or correction
- more synthesis burden after the fact
- duplicate findings without live consolidation
- less visible collaborative texture

## Comparison Metrics

Use a 1-5 score for each metric, where:

- `1` = poor
- `3` = acceptable
- `5` = strong

### 1. Orbit Specificity

Does the method produce findings that are clearly about Orbit rather than about
generic app work or generic AI process?

Signals:

- names Orbit-specific design or workflow issues
- references command-center goals
- distinguishes Orbit from chat-like behavior

### 2. Persona Fidelity

Does the method keep persona roles distinct, believable, and auditable?

Signals:

- one active persona per contribution
- little role blur
- outputs feel aligned with persona responsibility

### 3. Evidence Quality

Are findings tied to specific artifacts, behaviors, tests, screenshots, or
review observations?

Signals:

- references to files, tests, screenshots, or review evidence
- low amount of vague praise or vague criticism

### 4. Finding Quality

How sharp, useful, and non-obvious are the findings?

Signals:

- catches real issues
- avoids empty repetition
- separates symptom from cause

### 5. Actionability

Does the method generate `Start Doing` and `Stop Doing` items that can be
turned into real next-step changes?

Signals:

- owners can be assigned
- checkpoints can be named
- items are bounded rather than broad

### 6. Product Sensitivity

Does the method catch look, feel, layout, and interaction problems at Orbit's
quality bar?

Signals:

- identifies UI and interaction failures
- notices when the product is explaining itself instead of embodying itself
- distinguishes functional success from design success

### 7. Process Sensitivity

Does the method catch failures in the multiagent, squad, or retrospective
process itself?

Signals:

- notices missing delegation
- notices retrospective ritual failures
- notices false confidence or false credit

### 8. Disagreement Handling

How well does the method surface, sharpen, and resolve meaningful
disagreements without collapsing them into mush?

Signals:

- disagreement is visible
- disagreement is evidence-backed
- disagreement produces sharper final language instead of vaguer compromise

### 9. Synthesis Burden

How hard is it for Samwise to reduce the raw outputs into one canonical
Starfish?

Scoring note:

- `5` = easy and clean synthesis
- `1` = heavy cleanup, heavy deduplication, or ambiguous contradictions

### 10. Turnaround Time

How efficient is the method in producing a reviewable canonical retrospective?

Scoring note:

- `5` = fast without obvious quality loss
- `1` = slow enough to meaningfully drag the Orbit loop

## Suggested Weighting

If one final weighted score is needed, use:

- Orbit Specificity: `14`
- Persona Fidelity: `14`
- Evidence Quality: `14`
- Finding Quality: `14`
- Actionability: `10`
- Product Sensitivity: `10`
- Process Sensitivity: `10`
- Disagreement Handling: `5`
- Synthesis Burden: `4`
- Turnaround Time: `5`

Total: `100`

This weighting favors Orbit truthfulness and persona/process integrity over raw
speed.

## Minimum Viability Gates

Even if a method scores well overall, it should not become Orbit's default
retrospective method if it fails either of these gates:

1. `Persona Fidelity` below `4 / 5`
2. `Evidence Quality` below `4 / 5`

Orbit should not optimize for speed or convenience at the cost of trustworthy
persona behavior or evidence quality.

## How To Run The Head-To-Head

1. Freeze the shared evidence packet.
2. Record the evidence packet manifest used for the experiment.
3. Run both methods under the no-cross-contamination rule.
4. Save the raw participant outputs for both methods before synthesis.
5. Run the roundtable method and save:
   - participant outputs
   - canonical Starfish report
   - scoring notes
6. Run the fan-out method against the same packet and save:
   - participant outputs
   - canonical Starfish report
   - scoring notes
7. Score both methods against the comparison metrics.
8. Write one short comparison note naming:
   - which method won overall
   - which method produced better product findings
   - which method produced better process findings
   - whether Orbit should standardize on one default or use both for different
     situations

Weighted score alone is not enough.

The comparison note should also state:

- whether either method failed the minimum viability gates
- which method AJ would trust more for changing Orbit and the squad next

## Interpretation Guidance

Do not force a false single winner if the results split usefully.

Possible conclusions include:

1. `Roundtable is default`
   Use when persona fidelity and visible team reasoning are the main goal.
2. `Fan-out is default`
   Use when time pressure is high and persona separation matters most.
3. `Hybrid policy`
   Use fan-out for first-pass evidence generation, then a short roundtable for
   disagreement resolution and canonical synthesis.

The hybrid outcome is especially plausible for Orbit, because Orbit needs both:

- clean persona boundaries
- visible collaborative judgment

## Recommended Initial Hypothesis

Initial hypothesis:

- Fan-out will likely score better on turnaround time, synthesis transparency
  of raw pass artifacts, and persona separation.
- Roundtable will likely score better on visible team reasoning, disagreement
  handling, and collaborative legitimacy.

A likely final operating model for Orbit is:

- parallel fan-out first
- short roundtable second
- one canonical Starfish at the end

That hypothesis should be tested rather than assumed.

## Discussion Queue

These items are intentionally queued for discussion rather than treated as
settled defaults:

1. Should `Architectural Editor` become a required pass for architecture-heavy
   milestones, or stay optional?
2. Should `Rosie` participate only after the canonical Starfish exists, or
   should Rosie ever contribute a first-class comparison pass?
3. Should the weighting change after the first real comparison run, or should
   one run be treated as too noisy to recalibrate the rubric yet?

## Output Artifacts

The comparison run should ideally produce:

1. one evidence packet manifest
2. one roundtable retrospective packet
3. one fan-out retrospective packet
4. one comparison note
5. one canonical decision about default Orbit retrospective method

Suggested packet templates live in:

- `Docs/Orbit/Execution/retrospectives/`

## Revision Notes

- 2026-03-09: Added the first head-to-head methodology for comparing
  roundtable and fan-out Orbit retrospectives.
