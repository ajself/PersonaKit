# M4 Quality Bar

Status: Closed for M4 Closeout
Milestone: `M4`
Primary Owner: `orbit-meeting-coordinator`
Last Updated: 2026-03-21

## Purpose

Define what counts as impressive, review-worthy completion for visible
team-and-squad collaboration in Orbit.

`M4` is where group collaboration stops being a vague future promise and starts
becoming a trustworthy Orbit behavior. That means explainability, attribution,
and bounded orchestration quality are part of the milestone definition, not
optional polish.

## Non-Negotiable Standard

`M4` is reached only when the operator can target a team or squad naturally and
still inspect exactly how Orbit decided who should participate.

That means the milestone must be:

- deterministic
- attributable
- operator-inspectable
- bounded to inline collaboration
- strong enough that `M5` can build on it without reopening group basics

## Quality Attributes

### 1. Deterministic Target Expansion

High bar:

- the same target expands into the same participant set under the same workspace
  state
- inclusion and exclusion reasoning is visible before or with the resulting
  exchange
- target expansion stays Orbit-owned rather than provider-owned

Failure signs:

- participant sets drift for the same target without a visible reason
- exclusions are hidden or inferred only from absence
- routing logic feels magical instead of inspectable

Evidence:

- `README.md`
- `Packet-02-Target-Expansion.md`
- `Validation-And-Review-Matrix.md`

### 2. Boundary Discipline Between `M4` And Later Milestones

High bar:

- inline collaboration remains the center of gravity for `M4`
- meeting promotion and continuity remain explicitly deferred to `M5`
- workstream handoff semantics remain explicitly deferred to `M7`

Failure signs:

- packet docs quietly assume promoted meetings or linked workstreams
- `M4` planning language reopens later-milestone scope
- participation state begins carrying broader continuity behavior than this
  slice requires

Evidence:

- `README.md`
- `Decision-Register.md`
- `Packet-03-Inline-Group-Reply-Flow.md`

### 3. Participation Legibility

High bar:

- participant roles are visible enough that the operator can tell what Orbit
  expects from each participant
- completion state is understandable without reconstructing internal runtime
  transitions
- partial failure is explicit instead of hidden inside aggregate success

Failure signs:

- the operator cannot tell whether a group exchange is still active or done
- participant roles are implied rather than stated
- one participant failure disappears behind a general "group replied" outcome

Evidence:

- `Packet-04-Participation-Roles-And-Completion-Semantics.md`
- `Validation-And-Review-Matrix.md`

### 4. Trust And Inspectability

High bar:

- AJ can review the expansion path, inclusion reasons, and visible state without
  needing debugger-only evidence
- product, interaction, and validation review each have named evidence
- the trust story is strong enough to justify later coordinator expansion

Failure signs:

- trust claims rely on implementer explanation rather than artifacts
- participant reasoning appears only in code comments or logs
- the milestone can only be defended by saying "the system knows what to do"

Evidence:

- `Packet-05-Trust-And-Inspectability.md`
- `Validation-And-Review-Matrix.md`

### 5. Dossier Readiness

High bar:

- the dossier meets the frozen milestone standard instead of existing as one thin
  README
- each packet has explicit grounding, scope, stop points, and failure
  dispositions
- later execution can start from the packet docs without improvising the basics

Failure signs:

- packet order exists only in the README and not in packet-level planning notes
- reviewers must infer validation ownership or stop points
- later runtime work would still need to invent the milestone contract on the fly

Evidence:

- `README.md`
- `Decision-Register.md`
- `Packet-01-Group-Structure-Assumptions.md`
- `Packet-02-Target-Expansion.md`
- `Packet-03-Inline-Group-Reply-Flow.md`
- `Packet-04-Participation-Roles-And-Completion-Semantics.md`
- `Packet-05-Trust-And-Inspectability.md`

## Disqualifying Shortcuts

Any of these mean `M4` is not complete:

- ad hoc roster behavior remains the real routing model
- `M4` quietly absorbs `M5` meeting promotion or `M7` workstream behavior
- exclusions or partial failures remain invisible to the operator
- group collaboration is considered trustworthy because it "works" once without a
  reviewable evidence package

## What "Impressive" Looks Like

An impressive `M4` result means a reviewer can say:

- Orbit can explain who was asked and why
- inline group replies still feel attributable and bounded
- the operator can see when a group exchange is active, partial, failed, or done
- the dossier is strong enough that the first runtime packet does not need to
  invent its own rules

If the result only proves that multiple personas can answer, it is not enough.
If the result proves that group collaboration is trustworthy and reviewable, it
is.
