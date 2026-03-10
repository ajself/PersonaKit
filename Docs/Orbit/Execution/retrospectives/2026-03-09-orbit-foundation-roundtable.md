# Orbit Roundtable Retrospective

- Date: 2026-03-09
- Objective: Run the first Orbit roundtable retrospective against the
  foundation checkpoint and compare it to the fan-out method.
- Scope: `codex/orbit-foundation` MVP checkpoint through post-build review
- Evidence Packet:
  - `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
- Facilitator:
  - `Samwise`

## Participants

1. `Senior SwiftUI Engineer`
2. `Venture Product Steward`
3. `Studio Interaction Quality Lead`
4. `Studio Coverage Architect`
5. `Samwise`

## Turn Order

1. `Senior SwiftUI Engineer`
2. `Venture Product Steward`
3. `Studio Interaction Quality Lead`
4. `Studio Coverage Architect`
5. `Samwise` synthesis turn

## Participant Starfish Outputs

### Senior SwiftUI Engineer

#### Keep Doing

1. Keep the Orbit surface bounded around the four proving-loop surfaces:
   workspace context, durable roster, conversation, and memory review.
2. Keep shipping activation-trace visibility in the discussion surface.
3. Keep snapshot coverage and deterministic behavior as part of the UI bar.

#### Less Of

1. Less view-owned product policy embedded directly in the panel.
2. Less conditional UI language and emphasis behavior.

#### More Of

1. More explicit layout-composition review.
2. More presentation-model-driven UI.
3. More manual product-feel review before calling a checkpoint complete.

#### Stop Doing

1. Stop defaulting the roster into a highlighted Samwise state.
2. Stop changing the primary CTA between `Send` and `Invite Group`.
3. Stop leaning on inline help inside the core panel to explain the product.

#### Start Doing

1. Start from a neutral roster state and let emphasis appear only from explicit
   address or recent-activity rules.
2. Start treating top alignment and vertical stability as explicit acceptance
   criteria for the Orbit panel.
3. Start requiring a dedicated design-review pass on Orbit surfaces before
   checkpoint closeout.

#### Evidence

1. `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
2. `Docs/Orbit/Execution/2026-03-09-orbit-foundation-retrospective.md`
3. `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`

#### Disagreements Or Clarifications

1. The current inline help execution is clearly wrong, but that does not prove
   Orbit can never have revealable guidance.
2. Some architecture judgments are inferred from shipped behavior plus self
   review rather than a fresh implementation audit.

### Venture Product Steward

#### Keep Doing

1. Keep defending the MVP as a command center with visible workspace context,
   durable collaborators, conversation, and inspectable activation traces.
2. Keep the product bar tied to deterministic behavior and snapshot-backed
   validation.
3. Keep the checkpoint bounded around proving-loop behavior.

#### Less Of

1. Less inline explanation inside the core panel.
2. Less accidental product policy living in view state.
3. Less generous checkpoint storytelling when the screen is functional but has
   not passed a real product-feel review.

#### More Of

1. More acceptance criteria around first-open clarity.
2. More explicit review of neutral roster state, top anchoring, and vertical
   stability as product requirements.
3. More rigor on execution readiness: higher justified starting confidence,
   explicit reviewer participation, and a retrospective that proves the
   process.

#### Stop Doing

1. Stop default-highlighting Samwise or any other participant in the neutral
   state.
2. Stop changing the primary CTA between `Send` and `Invite Group`.
3. Stop relying on inline help to carry Orbit's product meaning.
4. Stop treating "real and testable" as equivalent to "product-ready."

#### Start Doing

1. Start every Orbit checkpoint with a product acceptance checklist alongside
   build, test, and snapshot gates.
2. Start requiring a dedicated design-review pass before calling an Orbit
   surface complete, even when it is intentionally early.
3. Start making persona contributions auditable by role and turn.
4. Start preserving the future memory-review shape in the product architecture
   without broadening this checkpoint into Phase 4 scope.

#### Evidence

1. `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
2. `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
3. `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
4. `Docs/Orbit/Execution/2026-03-09-orbit-foundation-retrospective.md`

#### Disagreements Or Clarifications

1. Activation-trace visibility is not optional polish; it is part of both the
   product promise and the milestone definition.
2. The long-term product vision includes memory review, but the current
   execution milestone explicitly excludes full memory candidate review.

### Studio Interaction Quality Lead

#### Keep Doing

1. Keep the bounded command-center surface.
2. Keep activation-trace visibility and deterministic behavior.
3. Keep snapshot-backed UI verification, but treat it as a floor for
   interaction quality, not proof of it.
4. Keep the command-center framing from the first-open experience.

#### Less Of

1. Less inline explanation carrying product meaning.
2. Less view-owned product policy such as conditional emphasis and label
   swapping.
3. Less conditional UI language that changes the meaning of the main action in
   place.
4. Less generosity in calling a functional screen clear or intentional before
   product-feel review happens.

#### More Of

1. More first-open clarity criteria tied to what AJ should understand in the
   first scan.
2. More top-anchored composition discipline.
3. More presentation-model-driven interaction rules.
4. More explicit manual interaction review with product-feel criteria.
5. More auditable reviewer participation so interaction-quality judgment is not
   inferred after the fact.

#### Stop Doing

1. Stop default-highlighting Samwise or any participant before AJ has
   expressed intent.
2. Stop changing the primary CTA between `Send` and `Invite Group`.
3. Stop using inline help disclosure as a structural crutch for meaning.
4. Stop treating expandable explanatory UI as harmless when it destabilizes
   vertical rhythm and top alignment.
5. Stop praising room feel when the roster emphasis model is still semantically
   noisy.

#### Start Doing

1. Start with a neutral roster default and make emphasis earned by clear
   interaction state.
2. Start enforcing a product acceptance checklist that includes neutral initial
   state, stable primary action language, and top-aligned composition.
3. Start requiring a dedicated design-review or interaction-quality pass before
   calling an Orbit checkpoint review-ready.
4. Start separating interaction policy from view code so product semantics are
   easier to inspect and harder to improvise.
5. Start capturing reviewer-backed interaction findings as first-class
   execution evidence.

#### Evidence

1. `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
2. `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
3. `Docs/Orbit/Execution/2026-03-09-orbit-foundation-retrospective.md`

#### Disagreements Or Clarifications

1. Activation traces belong in `Keep Doing`, not `Less Of`.
2. Reviewable should not mean interaction-ready. The current evidence supports
   real and testable, but not product-feel validated.

### Studio Coverage Architect

#### Keep Doing

1. Keep the Orbit surface bounded to the first checkpoint.
2. Keep activation-trace visibility, deterministic persistence, focused Orbit
   tests, and snapshot coverage as core proof surfaces.
3. Keep separating feature delivery success from process and persona-fidelity
   success.
4. Keep freezing evidence before synthesis.

#### Less Of

1. Less treating snapshot passes or deterministic behavior as implied product
   approval.
2. Less product policy living in view defaults, emphasis rules, and conditional
   CTA language.
3. Less explanatory copy doing semantic work that structure and stable
   interaction rules should carry.
4. Less self-authored retrospective confidence when reviewer-backed validation
   artifacts are missing.

#### More Of

1. More coverage around first-open semantics.
2. More manual verification evidence for top-anchored composition, restart
   durability, and product feel.
3. More auditable reviewer participation so persona contributions show up as
   artifacts, not internal lenses.
4. More explicit closeout language that separates feature outcome, process
   outcome, and persona-fidelity outcome.

#### Stop Doing

1. Stop default-highlighting Samwise or any participant through biased initial
   address state.
2. Stop changing the primary CTA between `Send` and `Invite Group`.
3. Stop using inline help disclosure as a crutch for meaning on the main Orbit
   surface.
4. Stop describing the run as a proven multiagent exercise when the evidence
   says `0` sub-agents and `1` active execution persona.

#### Start Doing

1. Start a checkpoint coverage contract that pairs deterministic checks with
   named manual review gates before calling Orbit usable or complete.
2. Start reviewer-backed acceptance scenarios for neutral first-open state, top
   alignment, restart durability, and activation-trace rendering.
3. Start requiring explicit validation ownership per persona.
4. Start turning retrospective `Start Doing` and `Stop Doing` items into owned
   checkpoint actions, not just observations.

#### Evidence

1. `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
2. `Docs/Orbit/Execution/2026-03-09-orbit-foundation-retrospective.md`
3. `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`
4. `Docs/Orbit/Execution/Orbit-Retrospective-Policy.md`

#### Disagreements Or Clarifications

1. More review is too soft unless it becomes coverage artifacts and named
   gates.
2. Snapshot-backed verification should remain, but only as a floor. It should
   never again be used as shorthand for product readiness.
3. Future memory-review shape does not belong in current checkpoint acceptance
   beyond staying explicitly out of scope.

## Canonical Starfish

### Keep Doing

1. Keep the first checkpoint tightly bounded around the Orbit command-center
   core: workspace context, durable collaborators, active discussion, and
   activation trace.
2. Keep deterministic technical validation and snapshot-backed UI verification
   as foundational proof, while being explicit that they are floors, not full
   product approval.
3. Keep correcting the written record when later review disproves earlier
   flattering language.

### Less Of

1. Less UI policy embedded in view defaults, especially biased roster emphasis,
   conditional CTA language, and explanatory help.
2. Less broad confidence and success language that blurs feature delivery,
   product readiness, and process validity.
3. Less storytelling that treats real-and-testable as if it already meant clear
   and intentional.

### More Of

1. More first-open clarity criteria and more top-anchored layout discipline.
2. More manual product and interaction review before checkpoint-closeout
   language broadens.
3. More auditable role participation and explicit validation ownership.
4. More evidence-led closeout accounting with feature, product, and process
   confidence separated.

### Stop Doing

1. Stop default-highlighting Samwise or any participant in the neutral state.
2. Stop changing the primary CTA between `Send` and `Invite Group`.
3. Stop using inline help as a structural crutch for Orbit meaning.
4. Stop treating deterministic tests and snapshots as if they prove product
   quality or multiagent-process success.
5. Stop describing the first run as a proven multiagent exercise.

### Start Doing

1. Start a required product acceptance checklist for Orbit checkpoints,
   including neutral roster state, stable action language, top alignment, and
   calm first-open readability.
2. Start a required design or interaction-quality review pass before using
   review-ready or MVP-candidate language.
3. Start a checkpoint coverage contract that pairs deterministic validation with
   named manual review artifacts.
4. Start making persona contributions, reviewer findings, and validation
   ownership explicit in the closeout packet.

## Action Items

1. Item: Create an Orbit product acceptance checklist covering neutral initial
   state, stable CTA language, top alignment, visible attribution, and help
   behavior.
   - Owner: Venture Product Steward + Studio Interaction Quality Lead
   - Checkpoint: before the next Orbit checkpoint review
   - Success signal: a checklist artifact exists and is used in the next Orbit
     review
2. Item: Create a checkpoint coverage contract for Orbit that pairs tests and
   snapshots with named manual-review artifacts and scoped confidence labels.
   - Owner: Studio Coverage Architect + Samwise
   - Checkpoint: before the rerun retrospective closes
   - Success signal: the next closeout distinguishes feature, product, and
     process confidence with explicit evidence sources
3. Item: Refine the Orbit UI to remove biased default emphasis, stabilize the
   primary CTA, and eliminate inline-help dependency from the main panel.
   - Owner: Senior SwiftUI Engineer + Studio Interaction Quality Lead
   - Checkpoint: next Orbit implementation slice
   - Success signal: the revised panel opens in a neutral state and no longer
     relies on help disclosure to explain the interaction model
4. Item: Add explicit required reviewer participation and validation ownership
   to the next Orbit execution attempt.
   - Owner: Samwise
   - Checkpoint: before the rerun begins
   - Success signal: revised plan/support docs name who reviews product,
     interaction quality, and validation, and what artifacts each must produce

## Scoring Notes

1. The roundtable sharpened the same core findings without much contradiction:
   the product and process problems were already visible in the evidence packet,
   but the turn-based method improved wording around proof versus product
   readiness.
2. The strongest extra value over fan-out was clarification: activation trace
   remained clearly in scope, future memory-review shape stayed out of current
   acceptance, and the room repeatedly rejected credit inflation from tests
   into product approval.
