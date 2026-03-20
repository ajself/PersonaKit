# M0 Agentic Execution Scaffold And Persona Coverage

Status: Ready For Planning Closeout
Primary Owner: `samwise`
Supporting Personas: `venture-product-steward`, `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Create the operating scaffold that lets later Orbit milestones run through AI
agents without hidden drift, fuzzy ownership, or missing persona coverage.

## Quality Standard

`M0` is not successful because a few planning files exist.

`M0` is successful only when the scaffold is precise enough that a later AI lane
can start from the dossier set and make high-quality decisions without relying
on thread memory, vague role assumptions, or improvised stop points.

For foundational product and stack choices, `M0` should make the AI lane's role
clear: build the approved direction, do not redefine it.

Bare-minimum paperwork is not a milestone win.

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Quality-Bar.md`
  definition of impressive `M0` quality and disqualifying shortcuts
- `Delegated-Handoff-Packet-Template.md`
  standard packet that later milestone lanes must start from
- `Persona-Coverage-Matrix.md`
  milestone-by-milestone owner, review, and gap map
- `Decision-Register.md`
  unresolved `M0` decisions, resolution criteria, and recommended defaults
- `Evidence-And-Exit-Criteria.md`
  required artifacts, review tests, and milestone-close rules
- `Tech-Stack-Posture.md`
  frozen stack posture and AI decision boundary for `M0` through `M3`
- `Sprint-Plan.md`
  completion-based sprint sequence for closing `M0`
- `Sprint-01-Scaffold-And-Handoff.md`
  first execution sprint for freezing dossier and handoff discipline
- `Sprint-02-Tech-Posture-And-Worktree-Freeze.md`
  sprint for hard-freezing stack posture and worktree execution boundaries
- `Sprint-03-Persona-Coverage-And-Identity-Closure.md`
  sprint for persona coverage, `ProdDoc`, and missing-persona staging
- `Sprint-04-AJ-Closeout-And-Release-Gate.md`
  sprint for AJ closeout, release gating, and handoff into `M1` and `M2`

## Preconditions

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md` is accepted as the
  top-level sequencing doc.
- The planning stack in `Docs/Orbit/Planning/` is aligned enough to act as a
  contract source.

## Scope Freeze

In scope:

- milestone dossier format
- delegated handoff packet format
- persona coverage map for all roadmap milestones
- approved tech-stack posture for `M0` through `M3`
- approved worktree execution boundary for Orbit-first milestone delivery
- `ProdDoc` identity decision
- missing-persona staging for later milestones

Out of scope:

- broad product redesign
- implementation work on Orbit runtime or UI
- implicit approval to create new personas without AJ review

## Required Inputs

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- current PersonaKit persona inventory under `.personakit/Packs/personas/`
- current agreed stack posture for Orbit client and server work

## Execution Packets

### Packet 1. Freeze The Dossier Standard

Outcome:

- every milestone has the same planning shape

Work:

- define the minimum dossier sections
- define what counts as packet, evidence, stop point, and handoff
- define the difference between milestone roadmap, milestone dossier, and lane
  execution notes

Done when:

- later milestone dirs can be filled without inventing new plan structure

### Packet 2. Freeze The Delegated Handoff Contract

Outcome:

- spawned lanes start with one bounded packet instead of open-ended context

Work:

- define required handoff inputs
- define what grounding must be loaded before work starts
- define what evidence a child lane must return
- define failure dispositions such as `blocked`, `needs-review`, and
  `grounding-blocked`

Done when:

- any later milestone can be delegated with one standard handoff packet

### Packet 3. Freeze Tech-Stack Posture

Outcome:

- later milestones stop treating foundational stack choices as agent freedom

Work:

- freeze the approved client posture for `M1` and `M2`
- freeze the approved server posture for `M3`
- freeze the AI decision boundary for what may and may not be chosen
- freeze the early no-cost and self-hosted posture
- freeze the non-main worktree execution rule and Orbit-first permission to
  restructure repo surfaces when the active milestone genuinely requires it

Done when:

- later milestone docs can point to one stack-posture artifact instead of
  re-deciding core technology choices

### Packet 4. Resolve Persona Coverage

Outcome:

- every milestone has a primary owner and review ring

Work:

- map roadmap milestones to existing personas
- flag milestones that require new personas before delegation
- decide whether `worktree-squad-lead` is enough for `M7` or whether
  `orbit-workstream-runner` should be created later

Done when:

- no milestone is left with an unnamed or blended execution identity

### Packet 5. Resolve The `ProdDoc` Question

Outcome:

- planning stops contradicting itself about the founding roster

Work:

- decide whether `ProdDoc` remains a product-facing collaborator label
- decide whether a formal PersonaKit persona must be created now
- update future milestone assumptions based on that decision

Done when:

- M1 and M2 can rely on one explicit collaborator naming decision

### Packet 6. Stage Missing Personas

Outcome:

- later milestones do not start with hidden persona gaps

Work:

- decide whether to create `orbit-meeting-coordinator` before `M4`
- decide whether to create `orbit-memory-gardener` before `M8`
- decide whether to create `orbit-platform-operator` or
  `orbit-server-steward` before `M13`

Done when:

- each missing persona is either approved for creation now or staged as a named
  prerequisite

## Subagent Use Pattern

Safe subagents:

- persona-fit review
- handoff-template review
- roadmap consistency review

Avoid:

- parallel write-heavy edits across PersonaKit packs until AJ approves the role
  map

## Evidence Package

- milestone dossier standard
- delegated handoff template
- milestone-to-persona coverage map
- stack posture note for `M0` through `M3`
- worktree execution rule for Orbit implementation lanes
- `ProdDoc` decision note
- missing-persona decision list

## Stop Points

- stop before later milestones rely on unresolved collaborator identity
- stop before later milestones rely on unapproved stack freedom
- stop before milestone execution begins on the main worktree or `main`
- stop before new persona creation unless AJ approves the additions
- stop if any milestone still needs more than one active execution persona

## Exit And Handoff

Exit only when AJ approves the role map, stack posture, and missing-persona
decisions.

Handoff forward to:

- `M1` with an approved identity contract lane
- `M2` with an approved founding-roster naming decision
