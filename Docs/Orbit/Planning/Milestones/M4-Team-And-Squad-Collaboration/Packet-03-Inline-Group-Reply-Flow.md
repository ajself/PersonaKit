# M4 Packet 3: Inline Group Reply Flow

Status: Ready For Planning Closeout
Packet Id: `M4-P3`
Milestone: `M4`
Execution Owner: `orbit-meeting-coordinator`
Review Personas: `venture-product-steward`, `studio-interaction-quality-lead`
Last Updated: 2026-03-20

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Define how group collaboration stays inline, attributable, and readable inside
  the existing discussion surface.
- This packet exists now because `M4` needs a trustworthy inline path before
  meeting promotion can be justified later.
- This is the right slice size because it keeps reply behavior separate from
  participation state and trust-proof work.

## Quality Bar

- group replies remain attributable inside the current thread
- the operator can understand the exchange without thinking it secretly became a
  meeting
- inline collaboration stays bounded and legible

## Preconditions

- `M4-P1` and `M4-P2` are coherent enough to define who was asked and why
- `orbit-meeting-coordinator` is approved and available through `PHR-0009`
- current post and thread attribution from earlier milestones remains trusted

## Grounding Requirements

- `.personakit/Sessions/orbit-meeting-coordinator-review.session.json`
- `.personakit/Sessions/orbit-meeting-coordinator-delivery.session.json`
- `Packet-02-Target-Expansion.md`
- `Decision-Register.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- live grounding required: `yes`

## Exact Scope

Include:

- inline group reply sequencing expectations
- attribution rules for participant replies
- the explicit boundary between inline collaboration and later meeting promotion

Exclude:

- promoted meeting posts
- continuity packages or meeting summaries
- workstream handoff behavior

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/`
- may create: inline-flow examples and product-review notes inside the `M4`
  dossier
- must not edit: `M5` meeting-continuity artifacts or runtime implementation
  paths in this packet

## Ordered Work

1. Define how group replies stay inline and attributable inside the current post
   or thread model.
2. Record the exact boundary that keeps this packet out of `M5`.
3. Return product and interaction review expectations for the inline path.

## Validation And Evidence

- inline group reply walkthrough examples
- explicit note describing what stays deferred to `M5`
- interaction review questions aligned with the validation matrix

## Failure Dispositions

- `blocked`
  expansion behavior is still unclear enough that inline replies would be
  misleading
- `needs-review`
  AJ needs to approve the inline boundary before any runtime-facing reply work
- `grounding-blocked`
  required coordinator grounding is unavailable
- `failed`
  the packet cannot keep inline replies legible without quietly depending on
  meeting behavior

## Stop Points

- stop if the inline path only makes sense by importing `M5` continuity behavior
- stop if reply attribution becomes weaker than the single-participant baseline

## Closeout Return Format

- inline reply contract defined
- examples and evidence produced
- open risks
- review decisions needed
- next recommended packet: `M4-P4`
