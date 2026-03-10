# Orbit retrospective method test report

- Date: 2026-03-09
- Author: `Samwise`
- Audience: Staff engineers, technical leads, and product/process owners
- Scope: Orbit foundation checkpoint retrospective-method experiment through the
  first completed head-to-head comparison

## Summary

Orbit's first implementation checkpoint surfaced a second engineering problem:
the project did not yet have a closeout method that could credibly evaluate
product quality, persona fidelity, and squad-process quality at the same time.

That gap mattered immediately in the `codex/orbit-foundation` lane. The branch
held a real Orbit checkpoint, but the conversation around that checkpoint kept
sliding between different kinds of truth: code truth, product truth, and process
truth. This report covers the first deliberate attempt to sort those truths
back into the right bins.

The team compared two retrospective methods against the same frozen evidence
packet:

1. `Roundtable`
   Persona-labeled specialist turns followed by live clarification and final
   synthesis.
2. `Fan-out`
   Parallel persona-labeled specialist passes followed by synthesis after all
   outputs were complete.

Result:

- `Roundtable` was the stronger single retrospective method.
- `Fan-out` was better at preserving persona separation and reducing
  turnaround time.
- `Hybrid` is the recommended Orbit default:
  fan-out first, short roundtable second, one canonical Starfish at the end.

This is not a generic process preference. It is a specific conclusion drawn
from the place Orbit is in right now:

- the product is still in formation
- the persona model is under test
- process claims must be backed by artifacts, not inferred from good intent

## Genesis

The immediate trigger was the gap between what Orbit set out to test and what
the first implementation run actually proved.

Orbit was not only trying to build a feature. It was also trying to prove that:

1. multiple personas could be used meaningfully
2. sub-agents could be paired with persona roles
3. the squad leader could coordinate a real multiagent loop
4. the retrospective system could collect learning without blurring the truth

That expectation had been outlined in Orbit planning and execution artifacts,
including:

- [Orbit-Execution-Plan.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Planning/Orbit-Execution-Plan.md)
- [Orbit-First-Checkpoint-Runtime-Model.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md)
- [Orbit-First-Checkpoint-Implementation-Breakdown.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md)
- [worktree-squad-cheat-sheet.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/PersonaKit/Development/worktree-squad-cheat-sheet.md)

The first Orbit coding checkpoint succeeded as a delivery exercise. A real
Orbit surface shipped. Tests passed. Snapshots existed. The branch was
reviewable.

But the user review and the subsequent self-audit made the real issue obvious:

- the feature checkpoint was real
- the product-quality claims were inflated
- the multiagent/process claims were not earned
- the retrospective notes were too flattering to the process as actually run

That mismatch changed the tone of the work. The question stopped being, "Did we
ship something?" and became, "Do we have a believable way to say what happened
here?" That, more than anything else, triggered the process-correction effort
before the next Orbit rerun.

## Problem statement

Orbit needed a milestone-closeout method that could answer four questions
without collapsing them into one vague judgment:

1. Did the feature work?
2. Did the product experience meet the intended bar?
3. Did the persona and squad process actually run as designed?
4. Can the resulting learning be trusted enough to guide the next Orbit plan?

The existing state was insufficient for three reasons:

1. `Feature evidence was stronger than product evidence.`
   Build, tests, and snapshots proved a bounded implementation checkpoint, but
   they did not prove that the Orbit experience was intentional or enjoyable.
2. `Persona usage was described more strongly than it was exercised.`
   The first run largely operated as single-agent delivery with internal role
   lenses rather than explicit multiagent participation.
3. `Retrospective ritual risked becoming theater.`
   A retrospective note could exist without the underlying participant-based
   process actually happening.

In short, Orbit needed a retrospective method that could withstand skeptical
technical review and still feel honest to the people in the room, not merely
one that looked organized.

## Goals of the test

The retrospective-method test aimed to determine:

1. which method better preserves persona fidelity
2. which method produces sharper Orbit-specific findings
3. which method produces more trustworthy next-step actions
4. whether Orbit should standardize on one default method or adopt a hybrid

The goal was not the fastest meeting format. The goal was the method that a
staff engineer could read, a product lead could trust, and the next Orbit run
could safely build on.

## Methods under test

### Roundtable

`Roundtable` runs specialist perspectives in visible turns. The facilitator
frames the evidence packet, the specialist personas respond one by one, and the
facilitator synthesizes only after the specialist turns complete.

In practice, roundtable is the method that most resembles a real room. It lets
the team hear itself think, challenge loose language and tighten claims before
those claims harden into policy.

Strengths hypothesized before the run:

- richer disagreement handling
- stronger collaborative legitimacy
- easier inspection of how claims sharpen over time

Risks hypothesized before the run:

- slower wall-clock time
- anchoring from earlier turns
- higher facilitator influence

### Fan-out

`Fan-out` runs specialist perspectives concurrently against the same evidence
packet. The raw outputs are preserved independently and synthesis happens only
after all passes finish.

In practice, fan-out is the cleaner machine. It protects role boundaries,
reduces waiting and preserves the raw shape of each specialist pass before the
group starts editing itself.

Strengths hypothesized before the run:

- stronger persona separation
- lower wall-clock time
- clearer raw artifacts

Risks hypothesized before the run:

- more duplication
- weaker visible challenge between participants
- heavier cleanup burden during synthesis

## Experiment design

The team defined experiment controls in
[Orbit-Retrospective-Methodology-Comparison.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/Orbit-Retrospective-Methodology-Comparison.md):

1. both methods had to use the same frozen evidence packet
2. both methods had to use the same Starfish output shape
3. one active persona per agent at a time
4. raw outputs had to be preserved before synthesis
5. the same scorer had to evaluate both methods

The frozen shared input was:

- [2026-03-09-orbit-foundation-evidence-packet.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md)

Specialist roles used in both methods:

1. `Senior SwiftUI Engineer`
2. `Venture Product Steward`
3. `Studio Interaction Quality Lead`
4. `Studio Coverage Architect`
5. `Samwise` as facilitator/synthesizer where applicable

Comparison metrics favored trustworthiness over speed:

- Orbit specificity
- persona fidelity
- evidence quality
- finding quality
- actionability
- product sensitivity
- process sensitivity
- disagreement handling
- synthesis burden
- turnaround time

That weighting was deliberate. Orbit does not currently suffer from a lack of
words. It suffers from the risk of saying the wrong kind of true thing too
confidently.

## Execution timeline

### 1. Post-implementation realization

After Orbit foundation shipped, the review surfaced two simultaneous truths:

1. the implementation checkpoint was real
2. the closeout story was overstated

That led to explicit corrections in Orbit execution notes and rerun-prep docs:

- [2026-03-09-orbit-foundation-retrospective.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/2026-03-09-orbit-foundation-retrospective.md)
- [2026-03-09-orbit-foundation-rerun-prep.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/2026-03-09-orbit-foundation-rerun-prep.md)

### 2. Retrospective policy was formalized

Orbit then gained explicit policy for when and how retrospectives must run:

- [Orbit-Retrospective-Policy.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/Orbit-Retrospective-Policy.md)

This established that milestone closeout was incomplete without review and
retrospective.

### 3. Comparison methodology was defined

The team then defined a head-to-head methodology for comparing roundtable and
fan-out:

- [Orbit-Retrospective-Methodology-Comparison.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/Orbit-Retrospective-Methodology-Comparison.md)

This moved the effort from a good idea in chat to a controlled comparison.

### 4. Runnable artifacts were created

Orbit created:

- evidence-packet templates
- roundtable and fan-out packet templates
- a comparison scorecard
- a final decision template

Then the first real run artifacts were instantiated for the Orbit foundation
checkpoint. This was the moment the work stopped being retrospective theory and
became a real operating test.

### 5. Both methods were run

The two methods were executed against the same evidence packet:

- [2026-03-09-orbit-foundation-fan-out.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-fan-out.md)
- [2026-03-09-orbit-foundation-roundtable.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-roundtable.md)

### 6. Both methods were scored and interpreted

The comparison outputs were scored and a method decision was produced:

- [2026-03-09-orbit-foundation-comparison-scorecard.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-comparison-scorecard.md)
- [2026-03-09-orbit-foundation-comparison-decision.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-comparison-decision.md)

## What the test found

### 1. Both methods reached the same core truth

This was the most important outcome.

The methods did not disagree about the central state of Orbit:

- the feature checkpoint is real
- the product design bar was not yet met
- the worktree/lane process is useful
- the original build pass did not meaningfully prove the intended multiagent
  model

That convergence matters because it suggests the findings are not artifacts of
one facilitation style. The team reached the same uncomfortable truths whether
it spoke in parallel or in sequence, which is exactly what a trustworthy method
should force.

### 2. Roundtable produced sharper final judgment

Roundtable performed better when Orbit needed:

- clarification of ambiguous claims
- better language around proof vs product readiness
- visible handling of disagreement
- stronger action framing for plan changes

That is why the scorecard gave Roundtable higher marks on:

- finding quality
- actionability
- product sensitivity
- disagreement handling

Put plainly, roundtable was better at helping the team say the hard thing
cleanly. It created less room for flattering ambiguity.

### 3. Fan-out preserved persona discipline better

Fan-out performed better when Orbit needed:

- stronger one-persona-per-pass separation
- cleaner raw evidence artifacts
- faster first-pass evidence generation

That is why the scorecard gave Fan-out the edge on:

- persona fidelity
- turnaround time

Put plainly, fan-out was better at discipline. It let each persona do its own
job before the group started negotiating language.

### 4. Hybrid best matches Orbit's operating needs

Orbit does not merely need fast generation or polished meeting theater. It
needs:

1. clean persona-bounded evidence generation
2. visible collaborative refinement before policy or planning changes

The hybrid recommendation follows directly from that requirement:

1. run `Fan-out` first
2. run a short `Roundtable` second
3. synthesize one canonical Starfish closeout

That sequence matches the shape of the work. First preserve the distinct voices.
Then make them answer each other. Then write down what survived.

## Quantitative result

From the comparison scorecard:

- `Roundtable`: `94.4 / 100`
- `Fan-out`: `89.6 / 100`

Interpretation:

- if Orbit must choose a single method, `Roundtable` is the stronger choice
- if Orbit wants the most trustworthy operating model, `Hybrid` is the
  stronger choice

The small numerical gap is less important than the distribution of strengths.
Roundtable won because it improved judgment. Fan-out remained essential because
it improved discipline.

All minimum-viability gates passed:

- Roundtable persona fidelity
- Roundtable evidence quality
- Fan-out persona fidelity
- Fan-out evidence quality

## Technical and product findings reinforced by the test

The comparison produced stronger confidence in several concrete Orbit findings:

1. `Neutral state is wrong.`
   The Orbit UI should not open in a Samwise-biased state.
2. `Primary action language is unstable.`
   The CTA should not switch between `Send` and `Invite Group`.
3. `Inline help is compensating for unclear structure.`
   The panel should not need a help disclosure to explain what Orbit is on
   first open.
4. `Layout needs stronger anchoring.`
   Top alignment and stable composition should be explicit acceptance criteria.
5. `Tests and snapshots are necessary but insufficient.`
   They prove a technical floor, not product quality.
6. `Process success must be scoped.`
   A good coding checkpoint does not automatically mean the multiagent process
   succeeded.

This matters because the first Orbit run was good enough to tempt overstatement.
The comparison helped remove that temptation from the record.

## What the test proved, and what it did not

### What it proved

1. Orbit can run a controlled retrospective comparison with preserved evidence,
   distinct persona roles, explicit scoring, and actionable output.
2. The two methods generate meaningfully different strengths.
3. A hybrid retrospective process is not a compromise-by-default; it is the
   best-supported outcome from this specific run.

That is a meaningful gain. Orbit now has at least one place where the operating
model is more mature at the end of the checkpoint than it was at the start.

### What it did not prove

1. That Orbit's overall multiagent execution model is fully mature.
2. That future runs will produce the same result without recalibration.
3. That the current Orbit product experience is close to finished.
4. That roundtable or fan-out alone is sufficient for all future contexts.

## Risks and limitations

This test was rigorous enough to be useful, but not complete in every way.

Known limitations:

1. `Single checkpoint bias`
   The comparison was run against one Orbit checkpoint, not across multiple
   milestone types.
2. `Facilitator continuity`
   Samwise designed, ran, and scored the comparison, which is efficient but not
   fully independent.
3. `Product evidence still depends partly on thread review`
   The product findings were strongly grounded, but not all of them came from a
   separate formal usability session artifact.
4. `Multiagent maturity remains partial`
   The retrospective system improved faster than the core Orbit execution model
   that inspired it.

These limits do not invalidate the result, but they do limit how broadly it
should be generalized.

They also keep the tone of this report grounded. This was a real learning loop,
not a final proof of process excellence.

## Operational consequences

The immediate follow-up actions already identified by the team are:

1. revise Orbit execution and rerun-prep docs to make the `Hybrid`
   retrospective the default closeout path
2. add a frozen evidence manifest section and scoped confidence ledger to the
   next retrospective packet
3. convert the product and interaction findings into concrete acceptance
   criteria for the next Orbit implementation slice

Those actions are not cosmetic. They are the path from comparison result to
stronger Orbit execution.

They also mark a shift in posture. Orbit is no longer only asking how to ship
the next slice. It is also asking how to deserve its own conclusions.

## Current state

As of this report:

1. the first Orbit retrospective-method comparison has been fully run
2. both methods have preserved artifacts
3. the methods have been scored
4. the decision has been made:
   `Hybrid` is the preferred default, with `Roundtable` as the stronger
   single-method fallback
5. the branch contains the completed comparison artifacts and committed result

Current decision checkpoint:

- [2026-03-09-orbit-foundation-comparison-decision.md](/Users/ajself/.codex/worktrees/0ff2/PersonaKit/Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-comparison-decision.md)

Current moment:

Orbit now has a better way to learn from itself than it had when the first
foundation checkpoint shipped. That does not fix the Orbit UI, nor does it make
the squad model proven. What it does mean is that the next rerun can be judged
by a stronger, more falsifiable, and more persona-disciplined closeout process.

That is where the project stands now: not finished, not vindicated, but more
honest, better instrumented and better prepared for the next attempt.
