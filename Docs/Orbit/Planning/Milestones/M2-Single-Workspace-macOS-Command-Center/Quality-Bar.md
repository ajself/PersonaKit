# M2 Quality Bar

Status: Draft
Milestone: `M2`
Primary Owner: `senior-swiftui-engineer`
Last Updated: 2026-03-18

## Purpose

Define what counts as impressive, review-worthy completion for the first Orbit
macOS command-center checkpoint.

`M2` is the first place Orbit has to feel real as a product, not just as a plan.
That makes product quality, durability, and explainability part of the milestone
definition rather than optional polish.

## Non-Negotiable Standard

`M2` is reached only when the local Orbit room is good enough that a reviewer can
believe the product direction.

That means the checkpoint must be:

- visibly Orbit-specific
- durable across restart
- attributable and explainable
- restrained in scope
- supported by review evidence, not optimism

## Quality Attributes

### 1. Orbit-ness

High bar:

- the screen feels like a workspace command center, not generic persona chat
- workspace, roster, thread, and trace work together as one product idea
- the room metaphor is supported by structure and visible state, not only copy

Failure signs:

- the panel is basically a chat transcript plus participant chips
- the workspace boundary is visually weak or incidental
- the trace affordance feels bolted on rather than native to the product model

Evidence:

- `Command-Center-Experience-Bar.md`
- product acceptance result
- interaction-quality review artifact

### 2. First-Open Clarity

High bar:

- AJ can tell where they are, who is present, and what is active on first scan
- the panel composition is stable and top-anchored
- the interface does not need inline help just to make sense

Failure signs:

- a reviewer has to hunt for the workspace identity
- default highlight or action language creates false intent
- the surface needs explanatory scaffolding to feel coherent

Evidence:

- `Command-Center-Experience-Bar.md`
- product acceptance result

### 3. Durable Collaboration Loop

High bar:

- a short discussion can begin, persist, and survive restart cleanly
- speaker attribution remains visible and trustworthy
- seeded and empty states both feel intentional

Failure signs:

- thread persistence is flaky or partial
- attribution is technically present but not legible
- the discussion surface feels like a scratchpad rather than a room thread

Evidence:

- deterministic persistence checks
- restart verification notes
- validation closeout artifact

### 4. Multi-Participant Legibility

High bar:

- direct addressing is understandable
- lightweight multi-participant exchange feels intentional
- participant routing does not feel like opaque backend magic

Failure signs:

- the user cannot tell why someone responded
- multi-participant behavior looks accidental or random
- the response bridge starts behaving like an invisible orchestration engine

Evidence:

- `Golden-Checkpoint-Walkthrough.md`
- validation and review matrix results

### 5. Explainability Without Visual Overweight

High bar:

- activation trace is easy to inspect
- trace answers meaningful product questions without overwhelming the room
- trace visibility reinforces Orbit's identity rather than distracting from it

Failure signs:

- trace is absent or buried
- trace requires debug-style inspection to be useful
- trace UI becomes so heavy that it dominates the core conversation surface

Evidence:

- `Command-Center-Experience-Bar.md`
- `Golden-Checkpoint-Walkthrough.md`
- interaction-quality review artifact

### 6. Scope Discipline

High bar:

- the checkpoint remains local-first and M2-scoped
- there is no quiet drift into server, memory, or mobile work
- meeting behavior stays lightweight and in service of the proving loop only

Failure signs:

- implementation grows platform abstractions that are not needed yet
- M3 or later milestone concerns leak into the checkpoint
- the product surface broadens while the core room still feels weak

Evidence:

- `Rerun-Execution-Contract.md`
- review notes from product and architecture-adjacent passes

### 7. Evidence Quality

High bar:

- the attempt closes with product, interaction, validation, participant, and
  retrospective evidence
- reviewers can distinguish feature quality, product quality, process quality,
  and persona-fidelity quality
- milestone closeout is based on artifacts, not verbal confidence

Failure signs:

- only implementation evidence exists
- closeout depends on thread memory or demo narration
- the result is called good before the review packet is assembled

Evidence:

- `Evidence-And-Exit-Criteria.md`
- attempt-specific closeout artifacts under `Docs/Orbit/Execution/`

## Disqualifying Shortcuts

Any of these mean `M2` is not complete:

- Orbit still feels more like generic chat than command center
- the thread does not reliably survive restart
- multi-participant behavior is not explainable enough to review
- activation trace exists only as debug output or hidden metadata
- the lane broadens into server, memory, or mobile work before the checkpoint is
  convincingly proven
- the branch is described as `review-ready` without the required review packet

## What "Impressive" Looks Like

An impressive `M2` result means AJ can open the app and immediately feel:

- this is a room with durable collaborators
- the discussion persists and has structure
- responses are attributable and lightly explainable
- the product has its own interaction model, not a chat clone with ornamentation
- the closeout evidence is strong enough that the next milestone can trust the
  baseline

If the result only proves a panel exists, it is not enough.
If the result proves Orbit's first room is believable, it is.
