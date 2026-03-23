# M6 Packet 1: Freeze Object Definitions

Status: Ready For Planning Closeout
Packet Id: `M6-P1`
Milestone: `M6`
Execution Owner: `venture-product-steward`
Review Personas: `samwise`, `architectural-editor`, `studio-interaction-quality-lead`
Last Updated: 2026-03-22

## Header

- status: `needs-review`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass jobs and semantic required fields for attached `note`,
  `decision`, `reference`, and `artifact` objects.
- This packet exists now because `M5` now hands off a bounded meeting-output
  bundle, but `M6` still needs a crisp object boundary before runtime, UI, and
  attachment work begin.
- This is the right slice size because it sharpens object meaning without
  starting attachment plumbing, UI work, workstream behavior, or memory policy.

## Quality Bar

- each object has one clear job that does not need another object type to
  explain its basic purpose
- the accepted `M5` meeting-summary boundary survives intact, with
  `meeting_summary` remaining a `note`
- later `M6` packets can implement storage and surfaces without relitigating
  what each object means

## Preconditions

- `M5` is closed tightly enough to serve as the handoff boundary
- `RFC-0002` and the Orbit vision remain the runtime-model baseline
- `M6` planning stays attached to posts and meetings rather than inventing a
  second collaboration system

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/Meeting-Output-Examples.md`
- `Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/AJ-Closeout-Review-Artifact.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- live grounding required: `yes`

## Exact Scope

Include:

- one first-pass job statement for `note`, `decision`, `reference`, and
  `artifact`
- the semantic required fields later packets must preserve for each object type
- the difference between meeting-summary notes, decisions, references, and
  artifacts using the accepted `M5` bundle as input

Exclude:

- runtime schema, migrations, or attachment-record implementation
- attachment ordering, inspector UX, or editing flows
- artifact connector semantics, workstream handoff behavior, or memory behavior

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/`
- may create: one packet-local planning artifact for `M6-P1`
- must not edit: runtime source paths, `M5` dossier files, or later milestone
  dossiers in this packet

## Ordered Work

1. Freeze the `M5` handoff facts this packet inherits and must not reopen.
2. Freeze the first-pass job and semantic field floor for each structured
   object type.
3. Record explicit classification rules and deferred items so later `M6`
   packets stay bounded.

## Validation And Evidence

- packet note aligned with `M6` milestone scope and `M5` handoff input
- object-definition freeze covering jobs, required fields, boundary examples,
  and deferrals
- explicit note that `M5` meeting output examples remain accepted input rather
  than a contract to rewrite

## Packet 1 Closure Position

- `note`, `decision`, `reference`, and `artifact` remain attached structured
  objects rather than new post types
- `M5` remains the accepted proof that a meeting may end with one canonical
  `meeting_summary` note, explicit decision or no-decision truth, open
  questions, and follow-up references
- `M6-P1` does not change that accepted `M5` bundle; it only freezes how later
  `M6` work should interpret and extend those object meanings
- later `M6` packets may add attachment plumbing and inspectable surfaces, but
  they must preserve the field floor and object distinctions frozen here

## Packet 1 Working Contract

### Shared Attachment Floor

- every structured object is attached to one originating `post`
- every structured object keeps stable identity and creation time at the
  runtime layer
- every structured object carries explicit creator attribution through
  `created_by_participant_type` and `created_by_participant_id`
- required semantic fields below must stay explicit even when the value is
  "none recorded" or an empty ordered list; omission must not become a hidden
  semantics channel
- this packet freezes semantic required fields, not final SQL column names or
  attachment-join details
- later packets may refine storage shape only if the object meaning below
  remains intact

### M5 Boundary Carried Forward

- the canonical `meeting_summary` shell proven in `M5` remains a `note` with
  `note_type = meeting_summary`
- explicit `no_decision` meeting truth still means no canonical `decision`
  object is synthesized just to make the model feel symmetrical
- follow-up references proven in `M5` remain `reference` objects, not
  mini-notes or placeholder artifacts
- open questions remain part of the accepted `M5` meeting output bundle and are
  not reclassified into a fifth object type by this packet

### `note`

Job:

- preserve durable narrative context, recap, synthesis, or reflection attached
  to a post when the primary value is human-readable explanation

Required semantic fields:

- `note_type`
- `body`

Use `note` when:

- the object answers "what happened here?" or "what should a reviewer
  understand from this post or meeting?"
- the content is recap, synthesis, retrospective text, or other durable prose
- the collaboration needs a narrative layer without claiming a final choice or
  storing a produced deliverable

Do not use `note` for:

- the canonical record of an adopted, rejected, or superseded choice
- a pure citation to supporting context
- a produced file, bundle, image, or report that should be inspectable as an
  output

Meeting-summary rule:

- `meeting_summary` is the narrative container for meeting recap and roll-up
  context
- it may mention decision status, open questions, or supporting material, but
  it does not replace a `decision`, `reference`, or `artifact` when those need
  independent inspection

### `decision`

Job:

- preserve one durable record of a concrete choice or explicit rejection, along
  with why that call was made and what evidence supported it

Required semantic fields:

- `title`
- `decision_state`
- `body`
- `rationale`
- `tradeoffs`
- `dissent`
- `linked_reference_ids`

Decision field semantics:

- `body` carries the decision statement itself rather than meeting-recap prose
- `tradeoffs`, `dissent`, and `linked_reference_ids` stay explicit even when
  they resolve to "none recorded" or an empty ordered list

Use `decision` when:

- the object answers "what did we decide?" or "what choice was explicitly
  rejected or superseded?"
- the collaboration needs an inspectable call that can stand apart from meeting
  recap prose
- reviewers need to see rationale and evidence without rereading the whole
  thread

Do not use `decision` for:

- generic summary text
- open questions that remain unresolved
- raw supporting sources or produced outputs themselves

Decision rule:

- a `decision` object captures the call, not the entire meeting
- the required `linked_reference_ids` field means decision evidence must stay
  discoverable through references instead of disappearing into freeform prose
- if a meeting outcome is explicitly `no_decision`, preserve that truth rather
  than manufacturing a thin decision object

### `reference`

Job:

- cite supporting context that already exists elsewhere so the originating post
  can point to evidence, prior art, or follow-up material without burying links
  in thread text

Required semantic fields:

- `reference_type`
- `target`

Use `reference` when:

- the object answers "what source, record, or target should a reviewer
  inspect?"
- the main need is provenance, citation, or follow-up targeting
- the collaboration wants evidence or context linked cleanly to the originating
  post or decision

Do not use `reference` for:

- recap or synthesis text
- decision rationale that belongs in the decision object itself
- a produced deliverable that should be treated as an output artifact

Reference rule:

- references point at context; they do not own or redefine that context
- the same underlying file, document, or URL may be a `reference` in one
  context and an `artifact` in another; the deciding question is whether Orbit
  is citing supporting context or preserving produced output
- a follow-up issue, commit, document, or URL is a `reference` when it is being
  cited as supporting or downstream context rather than preserved as the
  primary output of the collaboration

### `artifact`

Job:

- preserve or point to a concrete output produced by the collaboration so
  deliverables remain inspectable from the originating post or meeting

Required semantic fields:

- `artifact_type`
- `storage_ref`

Use `artifact` when:

- the object answers "what did this collaboration produce?"
- the attached item is a deliverable, report, generated output, bundle, or
  other inspectable result
- the object should behave like output provenance rather than citation

Do not use `artifact` for:

- meeting recap text
- decision rationale or status
- a source being cited as evidence rather than an output of the collaboration

Artifact rule:

- artifacts are outputs, not merely links
- later packets may decide how files, bundles, and external handles are stored
  or previewed, but this packet freezes the semantic distinction that an
  artifact is produced result rather than supporting context

### Classification Guide From The Accepted M5 Bundle

- meeting recap text and roll-up context: `note` with
  `note_type = meeting_summary`
- explicit adopted, rejected, or superseded call: `decision`
- follow-up URL, document, commit, issue, or file path cited as supporting or
  downstream context: `reference`
- produced report, bundle, image, code output, or other result created by the
  collaboration: `artifact`
- open questions carried out of meeting completion: stay in the accepted `M5`
  meeting output bundle for now; not frozen as a fifth structured-object type
  here

### Explicitly Deferred

- exact SQL tables, columns, and join shapes
- attachment ordering, editing flows, and inspection UX
- artifact connector semantics and storage backends
- any rule that auto-launches `M7` workstream behavior from a `decision` or
  `artifact`
- journal, memory-candidate, or approved-memory behavior

## Failure Dispositions

- `blocked`
  required `M5` handoff or `M6` grounding inputs are missing or contradictory
- `needs-review`
  object meanings are frozen for packet review but not yet accepted for
  follow-on implementation
- `grounding-blocked`
  required local PersonaKit CLI grounding is unavailable
- `failed`
  object definitions cannot be frozen without reopening `M5` or smuggling in
  later-packet behavior

## Stop Points

- stop if freezing object definitions requires changing the accepted `M5`
  meeting output contract
- stop if note, decision, reference, and artifact cannot be distinguished
  without inventing attachment or connector behavior that belongs to later
  packets
- stop if this packet starts defining `M7` workstream execution or `M8` memory
  behavior

## Closeout Return Format

- object-definition freeze completed or explicitly blocked
- evidence produced
- open risks
- review decisions needed
- next recommended packet: `M6-P2`
