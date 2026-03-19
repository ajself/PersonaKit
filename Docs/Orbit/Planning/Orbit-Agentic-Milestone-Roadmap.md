# Orbit Agentic Milestone Roadmap

Status: Accepted
Owner: Samwise
Workspace: Orbit
Last Updated: 2026-03-18

## Purpose

Turn the Orbit vision and RFC set into a capability-ordered roadmap that an AI
agent can execute milestone by milestone without relying on thread memory or
improvised scope.

This roadmap is organized around milestone readiness, not time. A milestone may
be split into as many implementation loops, work packets, or review cycles as
needed. What matters is that each milestone has:

- a clear goal
- explicit scope boundaries
- named execution and review owners
- deterministic exit criteria
- stop points before the next milestone begins

Accepted here means this roadmap is the approved milestone-sequencing baseline
for Orbit planning. It does not mean every milestone listed here is already
implemented or closed.

## Source Of Truth

Primary source documents:

- `Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md`
- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`

Existing implementation-facing inputs that should anchor the earliest milestones:

- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
- `Docs/Orbit/Planning/Orbit-Proving-Loop.md`
- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Runtime-Model.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`

## Current Planning Stack

Use the planning files in this directory as a layered stack, not as competing
plans.

- `Orbit-Agentic-Milestone-Roadmap.md`
  top-level sequencing authority across all Orbit milestones
- `Orbit-Execution-Plan.md`
  active execution contract for the current first-checkpoint rerun boundary
- `Orbit-Proving-Loop.md`
  phase model and product-shape rationale for the first proving loop
- `Orbit-macOS-Command-Center.md`
  product-facing definition of what the first Orbit room should feel like
- `Orbit-First-Checkpoint-Runtime-Model.md`
  minimum local runtime and persistence boundary for `M1` and `M2`
- `Orbit-First-Checkpoint-Implementation-Breakdown.md`
  codebase-facing file, module, and validation map for the first checkpoint
- `Docs/Orbit/Planning/Milestones/README.md`
  index for per-milestone dossiers that refine packet order, evidence, stop
  points, and handoff expectations

If a future planning edit makes two of these documents say the same thing at the
same level of detail, prefer consolidation over drift.

## Planning Rules For AI-Agent Execution

### 1. Parent Orchestration Stays With Samwise

Each milestone should have one parent planning/orchestration lane anchored to
`samwise`. Samwise owns:

- scope freeze
- handoff quality
- stop-point enforcement
- evidence collection
- milestone closeout language

### 2. One Active Persona Per Lane

Every delegated agent or subagent should have one authoritative operating
persona. Review personas may be listed separately, but no lane should blend
multiple active personas.

### 3. PersonaKit Grounding Comes Before Delegation

For every spawned lane:

- preferred grounding: live PersonaKit MCP
- allowed fallback: static PersonaKit export for bounded implementation or
  review work only
- failure disposition when grounding is unavailable: `grounding-blocked`

Planning, hiring, memory governance, and open-ended orchestration work should
not silently degrade to cached context.

### 4. Use Subagents Where They Help Most

The subagent guidance in the Codex and Simon Willison references points to the
same pattern:

- use subagents heavily for read-heavy exploration, summarization, test runs,
  review passes, and evidence synthesis
- use subagents in parallel when the work is independent
- be conservative with parallel write-heavy work
- keep one write owner per artifact surface at a time

### 5. Every Milestone Needs A Review Ring

No milestone should be treated as complete until it has:

- one primary execution owner
- at least one non-implementation review owner
- explicit validation evidence
- an AJ review gate before promotion to the next milestone

### 6. Orbit Must Prove Control Before Breadth

The roadmap should preserve the architectural order implied by the RFCs:

- identity anchoring before broad collaboration
- canonical runtime before multi-client sprawl
- governed memory before memory reuse
- server truth before offline/mobile convenience

## Persona Coverage For The Roadmap

### Covered Now

These existing personas are already good fits for early Orbit delivery:

- `samwise` - orchestration, continuity, handoffs, review pauses
- `venture-product-steward` - milestone framing, scope, acceptance, value
- `senior-swiftui-engineer` - client implementation
- `architectural-editor` - authored/runtime boundaries, invariants, review-first
  architecture checks
- `studio-coverage-architect` - deterministic validation and regression
  protection
- `studio-interaction-quality-lead` - command-center, meeting, and review-surface
  usability
- `studio-reliability-engineer` - async, realtime, offline, and state-transition
  reliability
- `studio-integration-coordinator` - integration gates and invariant checks
- `worktree-squad-lead` - bounded execution loops and delivery sequencing

### Covered With Gaps

- `workstream runner` - current coverage can be split between
  `worktree-squad-lead` and domain implementation personas for early milestones,
  but a dedicated Orbit-native execution identity may become necessary once
  workstreams become first-class product behavior
- `ProdDoc` collaborator identity - the first checkpoint now treats `ProdDoc` as
  the product-facing collaborator label mapped to `venture-product-steward`;
  create a formal persona later only if a milestone needs a distinct authored
  identity

### Likely Missing And Worth Creating Before Later Milestones

- `orbit-meeting-coordinator` - needed before group-targeting and meeting
  behavior are delegated to an AI lane
- `orbit-memory-gardener` - needed before journaling, candidate review, memory
  promotion, and contradiction handling are delegated
- `orbit-platform-operator` or `orbit-server-steward` - needed before server
  operations, deployment stewardship, backups, replay integrity, and multi-client
  operational work are delegated

Optional later addition if the generic delivery roles become too stretched:

- `orbit-workstream-runner` - explicit execution identity for non-chat workstream
  lanes

## Milestone Sequence

### M0. Agentic Execution Scaffold And Persona Coverage

Goal:
Create the operating scaffold that lets later milestones run through AI agents
without hidden drift.

Current state:

- accepted through the recorded AJ approval outcome in
  `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Planning-Closeout-Packet.md`

Primary owner:
`samwise`

Supporting personas:

- `venture-product-steward`
- `architectural-editor`

Scope:

- freeze the milestone dossier format used for later Orbit work
- define the standard delegated handoff packet for spawned lanes
- map each major Orbit role to an existing persona, gap, or explicit stop point
- freeze the `ProdDoc` -> `venture-product-steward` identity decision for the
  first checkpoint
- decide whether `orbit-meeting-coordinator`, `orbit-memory-gardener`, and
  `orbit-platform-operator` should be created now or queued as explicit
  prerequisite work for later milestones

Recommended subagent packets:

- persona-fit review
- handoff-template review
- roadmap consistency review

Exit criteria:

- every later milestone has a named execution persona
- every later milestone has at least one named review persona
- missing personas are either created or explicitly staged as prerequisites
- delegated grounding rules are frozen and reusable

Review gate:

- AJ approves the role map and any new persona creation before later milestones
  depend on them
- AJ approved the `M0` role map, stack posture, and staged missing-persona
  plan for `M1` through `M3`

References:

- Vision operating model
- RFC-0001 authored/runtime split
- RFC-0004 coordinator visibility requirements
- RFC-0005 stewardship requirements

### M1. Identity And Activation Foundation

Goal:
Make one Orbit response fully attributable before collaboration expands.

Primary owner:
`architectural-editor`

Supporting personas:

- `senior-swiftui-engineer`
- `studio-coverage-architect`

Scope:

- implement the minimum workspace persona instance and collaborator model
- define the activation sequence and failure states
- persist activation records, contract snapshots, and activation memory-source
  references
- block on ambiguity instead of silently guessing workspace, collaborator,
  directive, or skill authority
- lock the authored-truth vs runtime-truth boundary in code and artifacts

Recommended subagent packets:

- RFC-0001 activation-trace audit
- RFC-0003 identity-boundary audit
- deterministic validation design

Exit criteria:

- one response can be traced to a workspace persona instance
- the active directive, kits, authorized skills, and stop points are inspectable
- ambiguous activation cases fail closed
- test coverage proves activation attribution and failure handling

Review gate:

- architecture and coverage review must pass before UI breadth increases

References:

- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`

### M2. Single-Workspace macOS Command-Center Proving Loop

Goal:
Prove the core Orbit room experience in one workspace before broadening the
platform.

Primary owner:
`senior-swiftui-engineer`

Supporting personas:

- `venture-product-steward`
- `studio-interaction-quality-lead`
- `studio-coverage-architect`

Scope:

- one visible Orbit workspace in the macOS app
- founding roster shown as durable participants
- durable thread and message persistence across restart
- direct participant addressing and a lightweight multi-participant exchange
- lightweight activation-trace visibility in the command-center surface

Recommended subagent packets:

- UI-shell implementation
- persistence and fixture generation
- snapshot and workflow validation
- product acceptance review

Exit criteria:

- AJ can open Orbit and immediately see the workspace and roster
- AJ can start or continue a discussion thread
- the thread survives restart
- responses are visibly attributed
- activation context is inspectable enough that Orbit does not feel like generic
  chat

Review gate:

- run the command-center and first-checkpoint acceptance review before calling
  the proving loop complete

References:

- `Docs/Orbit/Planning/Orbit-macOS-Command-Center.md`
- `Docs/Orbit/Planning/Orbit-Proving-Loop.md`
- `Docs/Orbit/Planning/Orbit-Execution-Plan.md`
- `Docs/Orbit/Planning/Orbit-First-Checkpoint-Implementation-Breakdown.md`

### M3. Canonical Orbit Server And Runtime Backbone

Goal:
Move Orbit from a proving surface to one canonical collaboration runtime.

Primary owner:
`studio-integration-coordinator`

Supporting personas:

- `architectural-editor`
- `senior-swiftui-engineer`
- `venture-product-steward`
- `studio-reliability-engineer`
- `studio-coverage-architect`

Scope:

- introduce Orbit Server as the canonical source of truth
- implement the minimum RFC-0002 phase-1 runtime records on the server:
  workspace, channel, workspace_persona, post, thread, message,
  post_participant, post_event, post_link, persona_activation, and agent_run
- add a realtime event stream
- add the first artifact-storage abstraction
- make the macOS client a surface over canonical server state instead of the
  long-term owner of truth

Recommended subagent packets:

- schema and transaction design
- realtime transport spike
- client integration lane
- reliability and replay test lane

Exit criteria:

- there is one authoritative server-backed collaboration runtime
- the macOS client reads and updates canonical state through server paths
- realtime updates reflect durable state rather than a second truth source
- the proving-loop semantics from M1 and M2 survive the migration unchanged

Review gate:

- architecture, reliability, and coverage review must pass before mobile work or
  richer collaboration logic begins

References:

- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`

### M4. Team And Squad Collaboration With Visible Coordinator Expansion

Goal:
Let the operator ask a group for input and inspect why each participant was
included.

Primary owner:
`orbit-meeting-coordinator` if available, otherwise stop and create it before
delegating this milestone

Supporting personas:

- `samwise`
- `venture-product-steward`
- `studio-interaction-quality-lead`
- `studio-coverage-architect`

Scope:

- add team and squad addressing
- expand group targets into workspace persona instances
- record inclusion and exclusion reasons
- support inline group replies in post threads
- expose participation roles and visible completion semantics for basic group
  exchanges

Recommended subagent packets:

- coordinator logic and policy implementation
- roster reasoning review
- trust and inspectability review
- multi-participant validation suite

Exit criteria:

- the operator can target a team or squad naturally
- Orbit can explain why each participant was included
- group exchanges remain attributable and reviewable
- no participant appears through opaque routing

Review gate:

- AJ approves coordinator behavior before broader orchestration is treated as
  trusted product behavior

References:

- Vision product truth: ask a team and inspect why each participant responded
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`

### M5. Meeting Promotion And Continuity

Goal:
Let a message-thread discussion move into meeting mode or a promoted meeting post
without losing continuity.

Primary owner:
`orbit-meeting-coordinator`

Supporting personas:

- `venture-product-steward`
- `studio-interaction-quality-lead`
- `studio-coverage-architect`

Scope:

- lightweight meeting mode inside the originating discussion
- promoted meeting-post creation with explicit continuity links
- meeting-state and meeting-member runtime records
- visible completion state
- meeting outputs such as summary, decision or no-decision state, open questions,
  and follow-up references

Recommended subagent packets:

- meeting state machine lane
- continuity and linking lane
- summary-quality review
- interaction review for meeting ergonomics

Exit criteria:

- a post thread can enter meeting mode without breaking history
- Orbit can promote that work into a dedicated meeting post when needed
- the operator can inspect who participated, what happened, and what remains
  open

Review gate:

- continuity, promotion, and completion semantics must be reviewed before
  workstream handoff depends on meeting output

References:

- Vision product truth: message thread to meeting mode with continuity
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`

### M6. Structured Post Objects And Decision Packets

Goal:
Stop important context from disappearing into thread text.

Primary owner:
`venture-product-steward`

Supporting personas:

- `senior-swiftui-engineer`
- `studio-interaction-quality-lead`
- `architectural-editor`

Scope:

- add attached notes, decisions, references, and artifacts
- make them inspectable from posts and meetings
- preserve rationale, tradeoffs, dissent, and linked evidence for decisions
- keep structured objects attached to post context rather than inventing a second
  collaboration system

Recommended subagent packets:

- object model and attachment lane
- decision-packet UX lane
- product-quality review

Exit criteria:

- serious posts can accumulate durable structured outputs
- decisions carry rationale and evidence
- references and artifacts are discoverable from the originating collaboration
  context

Review gate:

- product and interaction review must confirm that structured objects clarify the
  workflow instead of adding opaque clutter

References:

- Vision Feature 4: notes, decisions, and references
- RFC-0002 phase 3

### M7. Workstream Posts And Execution Lanes

Goal:
Bridge discussion to execution without collapsing execution into chat.

Primary owner:
`worktree-squad-lead` for the first cut; promote to `orbit-workstream-runner` if
the execution role becomes too broad or too autonomous for the generic delivery
stack

Supporting personas:

- `samwise`
- `venture-product-steward`
- `studio-integration-coordinator`
- `studio-coverage-architect`

Scope:

- add workstream posts, workstream state, and assignment records
- support linked handoff from message posts and meeting posts into execution
  lanes
- stream progress, artifacts, and closeout back into Orbit
- keep execution status visible and separate from the originating collaboration
  thread

Recommended subagent packets:

- workstream model and lifecycle lane
- execution-handoff lane
- artifact-return lane
- validation and closeout lane

Exit criteria:

- a post can launch a workstream with visible status
- progress and artifacts return to the originating context
- closeout is explicit rather than implied
- workstream execution remains bounded and inspectable

Review gate:

- AJ reviews workstream handoff and closeout semantics before the system claims
  reliable follow-through

References:

- Vision product truth: a post launches a workstream and receives durable
  progress, artifacts, and closeout
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`

### M8. Journaling And Memory Candidate Review

Goal:
Turn important activity into reviewed learning proposals instead of automatic
behavioral drift.

Primary owner:
`orbit-memory-gardener` if available, otherwise stop and create it before
delegating this milestone

Supporting personas:

- `venture-product-steward`
- `studio-interaction-quality-lead`
- `studio-coverage-architect`

Scope:

- add journal entries and journal-source records
- add memory candidates and memory-review workflow
- support manual approve, reject, and revise actions
- show candidate source, proposed summary, proposed scope, and intended future
  influence

Recommended subagent packets:

- journal generation lane
- candidate staging lane
- review-surface UX lane
- governance validation lane

Exit criteria:

- important discussion, meeting, or workstream activity can produce journal and
  memory candidates
- the operator can review candidates explicitly
- raw runtime history does not become trusted memory by default

Review gate:

- memory governance review must pass before any approved memory is allowed to
  affect future activations

References:

- Vision product truth: important activity becomes reviewable journal and memory
  candidates
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- RFC-0002 phase 4

### M9. Approved Memory, Lineage, And Scoped Retrieval

Goal:
Let approved memory influence future work without becoming hidden magic.

Primary owner:
`orbit-memory-gardener`

Supporting personas:

- `architectural-editor`
- `studio-coverage-architect`
- `venture-product-steward`

Scope:

- add approved memory entries, memory links, and persona-global memory profiles
- enforce scope boundaries for workspace, workspace persona, persona-global, and
  optional organization memory
- make activation-memory-source linkage visible in traces
- support lineage inspection and safe retrieval rules

Recommended subagent packets:

- retrieval boundary implementation
- lineage and traversal lane
- activation trace review
- memory-scope regression suite

Exit criteria:

- an approved memory can influence a later response
- the operator can inspect which memory was used and why
- cross-scope contamination is blocked by default
- approved memory remains separate from authored persona definitions

Review gate:

- AJ reviews memory eligibility and traceability before Orbit treats memory reuse
  as a trusted feature

References:

- `Docs/Orbit/RFCs/RFC-0001-Workspace-Persona-Contract-Resolution-and-Activation-Model.md`
- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- RFC-0002 phase 5

### M10. Memory Gardening, Contradiction Handling, And Cross-Workspace Promotion

Goal:
Make memory maintainable over time instead of merely accumulated.

Primary owner:
`orbit-memory-gardener`

Supporting personas:

- `samwise`
- `venture-product-steward`
- `studio-coverage-architect`

Scope:

- duplicate clustering
- contradiction and supersession review
- scheduled gardening cadence
- richer cross-workspace promotion rules
- audits and quality metrics for long-term memory health

Recommended subagent packets:

- duplicate and contradiction analysis lane
- promotion-policy review lane
- audit and metric lane

Exit criteria:

- stale, duplicate, and conflicting memories can be reviewed intentionally
- cross-workspace learning is explicit and earned
- memory quality trends are visible enough to govern

Review gate:

- all cross-workspace promotion paths remain behind explicit AJ approval

References:

- `Docs/Orbit/RFCs/RFC-0005-Memory-Journaling-and-Gardening-Model.md`
- `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`

### M11. iPhone Client And Offline Governance

Goal:
Extend Orbit to quick interaction and approvals without creating a second truth
system.

Primary owner:
`senior-swiftui-engineer`

Supporting personas:

- `studio-reliability-engineer`
- `venture-product-steward`
- `studio-coverage-architect`

Scope:

- iPhone client
- notifications
- local draft queue and offline intent handling
- approval reconciliation on reconnect
- protection against stale or conflicting client-local assumptions

Recommended subagent packets:

- mobile surface implementation
- offline-state and reconciliation lane
- reliability review and conflict testing

Exit criteria:

- the iPhone client supports high-value lightweight interaction and approvals
- offline actions reconcile against canonical server state
- client convenience never bypasses review or canonical runtime rules

Review gate:

- reliability review must approve offline and stale-state handling before mobile
  governance is trusted

References:

- RFC-0006 phase 2

### M12. iPad Meeting Surface

Goal:
Make iPad materially better for meeting orchestration rather than merely a larger
client.

Primary owner:
`senior-swiftui-engineer`

Supporting personas:

- `studio-interaction-quality-lead`
- `orbit-meeting-coordinator`
- `venture-product-steward`

Scope:

- iPad meeting-first layouts
- roster and comparison surfaces
- richer collaboration panels for live facilitation
- preserve the same canonical backend and runtime semantics as macOS and iPhone

Recommended subagent packets:

- meeting ergonomics lane
- large-screen layout lane
- interaction-quality review lane

Exit criteria:

- the iPad client adds distinct meeting value
- meeting participation, comparison, and facilitation feel clearer than on phone
  or desktop alone
- no device-specific workflow contradicts the canonical Orbit runtime

Review gate:

- interaction review must confirm that iPad is a differentiated meeting surface,
  not a diluted macOS clone

References:

- RFC-0006 phase 3
- Vision platform and meeting-surface sections

### M13. Platform Operations, Historical Inspection, And Service Hardening

Goal:
Turn Orbit into a mature self-hosted platform rather than a promising prototype.

Primary owner:
`orbit-platform-operator` or `orbit-server-steward`

Supporting personas:

- `studio-integration-coordinator`
- `studio-reliability-engineer`
- `studio-coverage-architect`
- `architectural-editor`

Scope:

- deployment and backup stewardship
- replay integrity and historical inspection
- richer storage backends where justified
- analytics and quality visibility
- optional service decomposition only if the monolith-first shape stops serving
  the product

Recommended subagent packets:

- deployment and backup lane
- observability lane
- replay-integrity and restore test lane
- architecture review for any service split

Exit criteria:

- Orbit can be operated as a dependable self-hosted system
- historical state can be inspected and audited
- operational recovery paths are explicit
- service decomposition remains evidence-based rather than fashionable

Review gate:

- AJ reviews operational readiness before broader deployment or heavier multi-
  client reliance

References:

- RFC-0006 phase 4
- Vision self-hosted deployment and trust/control sections

## Capability Cuts

These milestones naturally group into four larger capability cuts.

### Cut A. Safe Agentic Foundation

- `M0`
- `M1`
- `M2`

Meaning:

- PersonaKit-grounded delivery is ready
- one workspace experience is believable
- responses are attributable before broader collaboration begins

### Cut B. Canonical Collaboration MVP

- `M3`
- `M4`
- `M5`
- `M6`
- `M7`

Meaning:

- Orbit has one canonical runtime
- group collaboration is explainable
- meetings preserve continuity
- structured outputs and workstreams make the system feel like a collaboration
  product rather than chat

### Cut C. Governed Learning MVP

- `M8`
- `M9`
- `M10`

Meaning:

- Orbit can propose, review, approve, and maintain durable learning without
  hidden drift

### Cut D. Multi-Client Platform Maturity

- `M11`
- `M12`
- `M13`

Meaning:

- Orbit becomes a serious multi-client self-hosted platform, not just a macOS
  proving surface

## Best First Action

Start with `M0`, then immediately turn the existing first-checkpoint Orbit plans
into the detailed dossier for `M1` and `M2`.

That gives the next AI delivery lane a bounded sequence:

1. apply the frozen role map and `ProdDoc` alias
2. freeze the activation and identity foundation
3. execute the macOS command-center proving loop already described in the Orbit
   planning docs

That is the smallest path that stays faithful to the vision while still creating
working product evidence quickly.
