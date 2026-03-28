# M7 Packet 4: Freeze Progress And Artifact Return

Status: Accepted
Packet Id: `M7-P4`
Milestone: `M7`
Execution Owner: `worktree-squad-lead`
Review Personas: `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect`
Last Updated: 2026-03-27

## Header

- status: `done`
- operator or reviewer required: `yes`
- packet type: `planning`

## Objective

- Freeze the first-pass contract for returning workstream progress, artifacts,
  and closeout back into Orbit without flooding the source discussion.
- This packet exists now because `M7-P1` through `M7-P3` already froze owner,
  runtime, and handoff boundaries, but Orbit still needs one explicit answer to
  how ongoing work becomes visible again to the operator.
- This is the right slice size because it freezes return semantics and source-
  of-truth rules without starting UI implementation, validation proof, or memory
  policy work.

## Quality Bar

- the operator can tell what changed in a workstream without rereading its full
  thread every time
- the source context stays readable and does not become a mirror of every
  workstream detail
- produced artifacts remain inspectable with one clear source-of-truth posture
- closeout, blockage, and failure return visibly enough that work does not feel
  like hidden background magic

## Preconditions

- `M7-P1` is accepted and remains the governing owner and approval contract
- `M7-P2` is accepted and remains the governing runtime-model contract
- `M7-P3` is accepted and remains the governing handoff contract
- `M6` remains the governing attachment boundary for notes, decisions,
  references, and artifacts
- the Orbit vision remains the baseline promise that a post can receive durable
  progress, artifacts, and closeout back into the same context

## Grounding Requirements

- local `personakit` CLI grounding for `samwise` with directive `apply-style`
- `README.md`
- `Packet-01-Freeze-Workstream-Ownership-And-Contract.md`
- `Packet-02-Freeze-Workstream-Runtime-Model.md`
- `Packet-03-Freeze-Handoff-From-Discussion-To-Execution.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md`
- `Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Product-And-Interaction-Review-Artifact.md`
- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- live grounding required: `yes`
- PersonaKit MCP grounding allowed: `no`

## Exact Scope

Include:

- the return-worthy progress-update contract from workstream back to source
  context
- the source-of-truth rule for artifacts produced by a workstream
- the closeout-return contract for completed, failed, cancelled, and blocked
  workstreams
- the explicit boundary between detailed workstream history and source-context
  summary return
- the minimum structured-object posture used for returned closeout and artifact
  visibility

Exclude:

- launch creation rules already frozen in `M7-P3`
- runtime-record semantics already frozen in `M7-P2`
- final UI layout, component hierarchy, or interaction design
- final event taxonomy, payload shapes, or schema decisions
- validation proof, review packet execution, or memory/journal policy work

## Write Scope

- may edit: `Docs/Orbit/Planning/Milestones/M7-Workstream-Posts-And-Execution-Lanes/`
- may create: one packet-local planning artifact inside the `M7` dossier
- must not edit: runtime source paths, `M5` or `M6` dossier files, or later
  milestone dossiers in this packet

## Ordered Work

1. Freeze which workstream updates are important enough to return to source
   context.
2. Freeze where artifacts and closeout records live versus how they are
   surfaced back to the source.
3. Freeze blocked, failed, and completed return rules so later packets do not
   imply hidden completion or silent loss of evidence.

## Validation And Evidence

- updated `M7` milestone README aligned with `M7-P4` acceptance and `M7-P5` as
  the next bounded packet
- packet note naming the progress-return contract, artifact source-of-truth
  rule, and closeout-return rule
- explicit language preventing source-thread flooding and attachment ambiguity

## Packet 4 Closure Position

- the workstream post remains the detailed execution home for live progress,
  produced artifacts, and closeout evidence
- the source context receives bounded returned signals about that work rather
  than a full mirror of the workstream thread
- artifacts and closeout stay inspectable from the source context without
  inventing a second workstream-specific artifact system
- later `M7` packets may implement the rendering and validation of these return
  signals, but they must preserve the return boundary frozen here or reopen
  `M7-P4`

## Packet 4 Working Contract

### Return-Worthy Progress Classes

- not every workstream-thread message returns to source context
- the first slice should return only progress that materially changes operator
  understanding of the workstream:
  - workstream launched
  - state transition into `in_progress`
  - explicit blocked state
  - significant checkpoint summary
  - artifact availability
  - terminal closeout state:
    `completed`, `failed`, or `cancelled`
- conversational detail, exploratory back-and-forth, and routine executor
  chatter remain on the workstream thread unless they materially affect status,
  scope, or review posture

### Source Context Return Contract

- the source context should be able to show, at minimum:
  - linked workstream identity
  - latest returned status
  - latest returned checkpoint or blocker summary
  - whether artifacts are now available
  - whether closeout has been recorded
- return signals should remain attached to the source context as bounded status
  or summary updates, not as a replay of the full workstream thread
- the source context should remain readable even if a workstream produces many
  detailed internal updates

### Workstream Thread As Detailed History

- the workstream thread remains the detailed place for:
  - ongoing progress notes
  - clarifications and review discussion
  - rationale for blockers or failures
  - closeout discussion leading to final return
- `post_event` remains the trace layer for lifecycle reconstruction and should
  support returned progress visibility without making the source context depend
  on debugger-only state

### Artifact Source-Of-Truth Rule

- produced artifacts remain attached to the workstream post as the primary
  durable output location
- the source context should receive explicit returned visibility to those
  artifacts rather than silently duplicating the same attachment records across
  multiple posts
- first-slice source-context visibility may use structured references, returned
  artifact summaries, or other bounded Orbit-visible linkage, but the underlying
  workstream artifact should remain the source of truth
- if a later packet wants mirrored artifact attachments on the source post, that
  should be treated as an explicit extension rather than assumed by this packet

### Closeout Return Contract

- every terminal workstream should return one explicit closeout signal to the
  source context
- the closeout return should name:
  - terminal status
  - whether requested outcome was achieved
  - concise closeout summary
  - whether artifacts or references were produced
  - any remaining follow-up or blocker truth
- the first-slice durable narrative closeout should remain compatible with the
  RFC `note_type = workstream_closeout`
- closeout should not require the operator to infer completion from silence,
  last-thread activity, or artifact presence alone

### Blocked And Failed Return Rules

- a workstream entering `blocked` must return a visible blocked summary to the
  source context, not just update the workstream's internal state
- a failed handoff belongs to `M7-P3`; a failed workstream after launch belongs
  here and must return visible failure state to the source context
- failure return should make clear:
  - that work started
  - that requested outcome was not achieved
  - whether partial progress or artifacts still exist
  - whether retry or follow-up remains possible
- cancelled workstreams should return explicit intentional-stop state rather
  than reading like a silent failure

### Structured Object Boundary

- workstream-produced artifacts continue to use the accepted `M6` artifact model
- returned closeout narrative should stay compatible with `note`
  rather than inventing a new top-level workstream-summary entity
- if a workstream produces decisions or references worth surfacing, they remain
  `decision` and `reference` objects under the accepted `M6` boundary
- `M7-P4` freezes return posture only; it does not reopen object semantics or
  attachment ordering from `M6`

### Boundary To Later Packets

- `M7-P4` freezes only what returns and where its durable source of truth lives
- `M7-P5` owns proof that review gates, closeout discipline, and visibility
  actually hold under real examples
- `M8` may later consume workstream closeout activity for journaling or memory
  review only through explicit later contracts

### Explicitly Deferred

- exact UI surfaces for progress cards, pills, or summary layouts
- exact event taxonomy and payload shapes for returned progress updates
- any automatic summarization cadence beyond the return-worthy class list above
- mirrored source-post artifact attachments as a default behavior
- memory or journaling behavior derived from workstream return signals

## Open Risks And Review Decisions Needed

- the choice to keep workstream artifacts as the primary source of truth while
  returning bounded visibility to the source context is the smallest coherent
  anti-duplication posture; later packets should not drift into silent dual-write
  behavior
- the line between significant checkpoint summary and noisy internal chatter
  remains a product judgment that later implementation will need to preserve
  carefully
- `workstream_closeout` note compatibility is now explicit; later packets must
  not invent a competing closeout object type
- `M7-P5` must prove that returned progress is visible enough without flooding
  the source thread

## Failure Dispositions

- `blocked`
  required return semantics or attachment boundaries are still unclear
- `needs-review`
  the return contract is coherent but not yet accepted for downstream work
- `grounding-blocked`
  required local PersonaKit grounding or repo-local authority evidence is not
  available
- `failed`
  the return model still depends on UI invention, silent duplication, or hidden
  completion inference to make sense

## Stop Points

- stop if returned progress cannot stay bounded without mirroring the full
  workstream thread into source context
- stop if artifact return would require silent dual-write attachment behavior to
  make sense
- stop if closeout would be implied rather than explicitly returned
- stop if `M7-P5`, UI, schema, or memory behavior is required to explain the
  return contract coherently

## Closeout Return Format

- progress-return contract frozen or explicitly blocked
- artifact source-of-truth rule named
- closeout return rule named
- open risks
- next recommended packet: `M7-P5`

## AJ Review Outcome

- AJ approved `M7-P4` as the progress, artifact, and closeout return baseline
  for `M7`.
- Returned visibility remains bounded to material progress, blocker, artifact,
  and terminal-closeout signals rather than mirroring the full workstream
  thread into source context.
- Workstream artifacts remain the primary durable source of truth, and returned
  source-context visibility must not drift into silent dual-write attachment
  behavior.
- Closeout, blocked, failed, and cancelled outcomes must remain explicit and
  compatible with the accepted `M6` object boundary and `workstream_closeout`
  posture.
- `M7-P5` may proceed only if it proves review-gate and closeout discipline
  without weakening the accepted `M7-P1` through `M7-P4` contracts.
