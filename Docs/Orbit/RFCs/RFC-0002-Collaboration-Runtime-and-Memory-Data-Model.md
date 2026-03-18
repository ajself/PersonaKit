# RFC-0002: Collaboration Runtime and Memory Data Model

## Status
Draft

## Authors
- AJ Self
- ChatGPT / ProdDoc

## Created
2026-03-08

## Last Updated
2026-03-17

## Related
- RFC-0001: Workspace Persona Contract Resolution and Activation Model
- RFC-0003: Workspace, Group, and Workspace Persona Instance Model
- RFC-0004: Teams, Squads, and Meeting Coordinator Model
- RFC-0005: Memory Journaling and Gardening Model
- RFC-0006: Orbit Multi-Client Platform Architecture
- Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC defines the conceptual data model for Orbit's collaboration runtime,
journaling, and memory systems.

Orbit is not modeled as a generic chat log. It is modeled as a collaboration
runtime built from:

- workspaces and channels
- workspace persona instances, teams, and squads
- durable posts
- threads attached to posts
- messages within threads
- linked meeting posts and workstream posts
- attached structured objects such as notes, decisions, references, and
  artifacts
- journals, memory candidates, and approved memory

PersonaKit remains the source of authored contract truth. Orbit owns the durable
runtime records that show where collaboration happened, what it produced, and
what should later be remembered.

This RFC does not define the final SQL schema or final API. It defines the
runtime shape that implementation should follow.

Terminology note:

- `user` initiates interactions in Orbit
- `operator` governs review, approval, and control
- in v1, the same person often plays both roles, but the distinction remains
  useful in the model

---

## 2. Motivation

Orbit is a collaboration product for persistent AI teams, not just a prompt
shell.

That means the runtime must support much more than a linear message history. It
must support:

- channels that organize collaboration
- message posts that anchor discussion
- message threads that accumulate replies
- promoted meeting posts with explicit participant state
- linked workstream posts with execution state
- attached notes, decisions, references, and artifacts
- activation and run trace records linked to collaboration context
- journaling and reviewed memory growth
- replayable state across macOS, iPhone, and iPad clients

The authored-definition model is appropriate for personas, directives, kits,
and contract rules, but it is not sufficient for runtime collaboration state.

Without a clear runtime data model, Orbit risks:

- fragmented post and thread history
- weak traceability between collaboration and activation
- ambiguous meeting and workstream state
- noisy or unsafe memory growth
- inconsistent behavior across clients and services

This RFC exists to define the durable runtime model before implementation
spreads across clients and backend services.

---

## 3. Problem Statement

Orbit needs a data model that can answer all of the following questions
reliably:

- What posts exist in a workspace and channel?
- Which thread belongs to a given post?
- Which messages belong to that thread?
- Which participants were involved in that post, thread, meeting, or
  workstream?
- Which workspace persona instance said a given thing, under which activation?
- Which linked posts were created as follow-up, dependency, or promotion?
- Which notes, decisions, references, and artifacts were attached to a post?
- Which journals were created from that post or thread activity?
- Which memory candidates and approved memories derived from that work?
- Which durable memories belong to a workspace, a workspace persona instance, a
  persona global profile, or the organization?
- How can future activations retrieve the right knowledge without
  cross-workspace contamination?

The system needs a model that is:

- relational
- inspectable
- evolvable
- safe for memory growth
- compatible with realtime clients
- compatible with later analytics and search

---

## 4. Goals

This RFC aims to establish a conceptual data model that:

- supports durable, replayable collaboration runtime state
- treats posts, threads, messages, and system events as distinct artifacts
- supports channels, teams, squads, and workspace persona instances as
  first-class runtime concepts
- models meeting posts and workstream posts as post-based collaboration objects
- records activation and run linkage explicitly without re-owning activation
  semantics already defined by RFC-0001
- supports attached structured objects for notes, decisions, references, and
  artifacts
- supports journaling as a first-class reflection layer
- supports memory candidates and approved memory as distinct stages
- enables scoped retrieval for:
  - workspace
  - workspace persona
  - persona global memory
  - organization
- supports lineage and traversal between durable memories
- supports future analytics, summaries, search, and trace inspection
- preserves Orbit and PersonaKit principles:
  - explicit over inferred
  - structure over autonomy
  - operators remain in control

---

## 5. Non-Goals

This RFC does not define:

- the final SQL schema or migrations
- the final API endpoints
- the final client sync protocol
- the final authentication model
- the final vector indexing or search ranking implementation
- the exact UI for channels, posts, threads, meetings, or workstreams
- full activation semantics or contract resolution precedence
- final prompt assembly or provider payloads

Activation semantics and contract resolution belong primarily to RFC-0001.
Workspace and persona-instance semantics belong primarily to RFC-0003.

---

## 6. Proposal

Orbit's runtime data should be modeled around five major domains:

1. Workspace structure
2. Collaboration runtime
3. Activation and execution records
4. Journaling
5. Memory

These domains should remain separate but linked through stable identifiers.

### Core design law

> PersonaKit defines who may act and under what rules.
> Orbit records where collaboration happened, what it produced, and what it
> should remember.

### Important shift

This RFC replaces a conversation-first model with a post-first model.

The primary durable collaboration object in Orbit is the `post`, not the generic
`conversation`.

In v1, posts come in three core types:

- `message`
- `meeting`
- `workstream`

Each post owns a thread. Messages live inside threads. Meeting and workstream
state attach to posts rather than existing as disconnected parallel roots.

---

## 7. Authored Truth Vs Runtime Truth

Orbit runtime records only make sense when separated from PersonaKit authored
truth.

### 7.1 PersonaKit authored truth

PersonaKit remains the source of:

- personas
- directives
- kits
- sessions
- skill authorization
- operating constraints

### 7.2 Orbit runtime truth

Orbit stores the runtime collaboration state in which those contracts operate:

- workspaces
- channels
- teams and squads
- workspace persona instances
- posts
- threads
- messages
- post participants
- post events
- post links
- attached structured objects
- activation and run records
- journals
- memory candidates and memory entries

### 7.3 Important boundary

RFC-0001 defines how activation resolves and what must be traceable.
RFC-0002 defines the runtime records and relationships that activation attaches
to.

---

## 8. Runtime Domains

```text
Workspace
  -> Channels
  -> Teams / Squads
  -> Workspace Persona Instances
  -> Posts
       -> Threads
            -> Messages
       -> Post Participants
       -> Post Events
       -> Post Links
       -> Attached Structured Objects
            -> Notes
            -> Decisions
            -> References
            -> Artifacts
       -> Type-Specific State
            -> Meeting State
            -> Workstream State
  -> Journals
  -> Memory Candidates
  -> Memory Entries
  -> Activation / Run Records
```

### 8.1 Sequence model

```text
User creates a message post or replies in an existing thread
  -> Post, thread, and message are persisted
  -> Post event is emitted
  -> Target expansion and activation run per RFC-0001
  -> Responses persist into the thread
  -> Orbit may promote the discussion into a linked meeting post
  -> Orbit may create a linked workstream post
  -> Notes, decisions, references, and artifacts attach to posts
  -> Journals are created from post and thread activity
  -> Memory candidates are proposed
  -> Operator review produces approved memory entries
```

### 8.2 Important separation

This RFC makes a hard distinction between:

- **Post** - durable collaboration object visible in Orbit surfaces
- **Thread** - ordered conversation attached to a post
- **Message** - individual authored entry in a thread
- **Post Event** - operational fact or state change
- **Structured Object** - attached note, decision, reference, or artifact
- **Journal** - reflective compression of post activity
- **Memory Candidate** - proposed durable learning
- **Memory Entry** - approved durable memory

That separation is essential for explainability and a legible UI.

---

## 9. Data Model

This section defines the conceptual runtime entities and relationships.

Where this section describes `workspace`, `channel`, `team`, `squad`,
`workspace_persona`, and `workspace_persona_membership`, RFC-0002 is mirroring
runtime record shapes that semantically belong to RFC-0003.

### 9.1 Workspace Structure

#### `workspace`

Top-level container for a venture, product, research stream, or internal
initiative.

Fields:
- `id`
- `slug`
- `name`
- `status`
- `created_at`
- `archived_at` nullable

Purpose:
- scopes channels
- scopes teams and squads
- scopes local memory
- scopes workspace persona instances

---

#### `channel`

Organizational surface for collections of posts inside a workspace.

Examples:
- general
- product
- engineering
- launch-readiness

Fields:
- `id`
- `workspace_id`
- `slug`
- `name`
- `purpose`
- `status`
- `created_at`
- `archived_at` nullable

Purpose:
- groups posts for navigation and visibility
- provides workspace-local structure without becoming a second source of truth

---

#### `team`

Durable group of workspace personas in a workspace.

Examples:
- product-core-team
- ios-shipping-team
- architecture-council

Fields:
- `id`
- `workspace_id`
- `slug`
- `name`
- `purpose`
- `created_at`

---

#### `squad`

Focused working group within a workspace.

Examples:
- onboarding-squad
- memory-system-squad
- app-sync-squad

Fields:
- `id`
- `workspace_id`
- `team_id` nullable
- `slug`
- `name`
- `purpose`
- `created_at`

Purpose:
- supports coordinator-based participant expansion
- enables smaller collaboration groups within or across teams

---

#### `workspace_persona`

Conceptual runtime entity representing the workspace persona instance described
in RFC-0001.

In this RFC, `workspace_persona` is schema shorthand for the `workspace persona
instance` term used in RFC-0001.

Fields:
- `id`
- `workspace_id`
- `persona_template_id`
- `display_name`
- `default_directive_override_id` nullable
- `status`
- `created_at`
- `archived_at` nullable

Purpose:
- local identity and memory anchor
- participant in posts, meetings, and workstreams
- carrier of workspace-local expertise

---

#### `workspace_persona_membership`

Links workspace persona instances to teams and squads.

Fields:
- `id`
- `workspace_persona_id`
- `team_id` nullable
- `squad_id` nullable
- `role_in_group`
- `created_at`

---

### 9.2 Posts, Threads, Messages, And Links

#### `post`

Primary durable collaboration object in Orbit.

Fields:
- `id`
- `workspace_id`
- `channel_id`
- `post_type`
  - `message`
  - `meeting`
  - `workstream`
- `created_by_participant_type`
  - `user`
  - `workspace_persona`
  - `system`
- `created_by_participant_id`
- `title` nullable
- `status`
  - `active`
  - `paused`
  - `completed`
  - `archived`
- `created_at`
- `archived_at` nullable

Purpose:
- top-level collaboration object visible in channels and command-center views
- anchor for a thread, structured objects, and linked follow-up work

Notes:
- `post_type = message` means a message post, which owns a thread
- `message` records are the individual entries inside that post's thread
- `post.status` is a coarse cross-type state for presentation and retrieval;
  detailed lifecycle remains in subtype records such as `meeting_state` and
  `workstream_state`

---

#### `thread`

Ordered conversation attached to a single post.

In v1, each post owns one primary thread.

Fields:
- `id`
- `post_id`
- `status`
  - `open`
  - `closed`
  - `archived`
- `last_activity_at`
- `created_at`
- `closed_at` nullable

Purpose:
- stores ordered conversation without turning the workspace into one flat log
- provides replayable reply context for a post

---

#### `message`

Individual authored entry within a thread.

Fields:
- `id`
- `post_id`
- `thread_id`
- `author_type`
  - `user`
  - `workspace_persona`
  - `system`
- `author_id`
- `reply_to_message_id` nullable
- `body`
- `message_format`
  - `plain_text`
  - `markdown`
  - `structured`
- `state`
  - `drafted`
  - `persisted`
  - `in_progress`
  - `completed`
  - `failed`
  - `superseded`
- `created_at`
- `updated_at`

Purpose:
- durable authored utterance
- replayable contribution from a user, collaborator, or system

---

#### `post_participant`

Participant roster attached to a post and its thread.

Fields:
- `id`
- `post_id`
- `participant_type`
  - `user`
  - `workspace_persona`
  - `system`
- `participant_id`
- `joined_at`
- `left_at` nullable
- `participation_mode`
  - `active`
  - `observing`
  - `invited`
  - `coordinator_managed`

Purpose:
- explicit roster for posts, especially meeting and workstream posts
- visibility into presence, invitation, and participation mode
- base participant layer extended by `meeting_member` and
  `workstream_assignment`

---

#### `post_event`

Operational system event attached to a post.

Fields:
- `id`
- `post_id`
- `thread_id` nullable
- `event_type`
- `payload`
- `created_at`

Examples:
- `post.created`
- `participant.invited`
- `activation.resolved`
- `meeting.promoted`
- `workstream.started`
- `workstream.failed`
- `artifact.attached`
- `memory.candidate_created`
- `memory.approved`

Purpose:
- runtime trace
- UI status reconstruction
- debugging and analytics

---

#### `post_link`

Relational link between posts.

Fields:
- `id`
- `from_post_id`
- `to_post_id`
- `link_type`
  - `origin`
  - `follow_up`
  - `dependency`
  - `promotion`
  - `related`
- `created_at`

Purpose:
- links message posts, meeting posts, and workstream posts without forcing a
  rigid tree
- preserves continuity across promotion and follow-on work

---

### 9.3 Type-Specific Post State

#### `meeting_state`

Meeting-specific lifecycle attached to a meeting post.

Fields:
- `post_id`
- `meeting_type`
  - `ad_hoc`
  - `squad`
  - `team`
  - `review`
  - `planning`
  - `retrospective`
- `status`
  - `created`
  - `active`
  - `summarizing`
  - `completed`
  - `failed`
- `started_by_participant_type`
  - `user`
  - `workspace_persona`
  - `system`
- `started_by_participant_id`
- `started_at`
- `completed_at` nullable

Purpose:
- supports structured deliberation without breaking post continuity

---

#### `meeting_member`

Explicit participant record for a meeting post.

Fields:
- `id`
- `meeting_post_id`
- `post_participant_id`
- `participation_role`
  - `facilitator`
  - `contributor`
  - `observer`
  - `summarizer`
- `selected_reason`
- `joined_at`
- `completed_at` nullable

Purpose:
- meeting-specific role and selection metadata layered on top of the base post
  roster

---

#### `workstream_state`

Execution-oriented lifecycle attached to a workstream post.

Fields:
- `post_id`
- `workstream_type`
  - `research`
  - `design`
  - `implementation`
  - `review`
  - `release`
  - `documentation`
- `requested_outcome`
- `status`
  - `draft`
  - `pending`
  - `idle`
  - `in_progress`
  - `blocked`
  - `completed`
  - `failed`
  - `cancelled`
- `requested_by_participant_type`
  - `user`
  - `workspace_persona`
  - `system`
- `requested_by_participant_id`
- `started_by_participant_type` nullable
  - `user`
  - `workspace_persona`
  - `system`
- `started_by_participant_id` nullable
- `requested_at`
- `started_at` nullable
- `completed_at` nullable
- `failure_reason` nullable

Purpose:
- supports linked execution work with visible state transitions

---

#### `workstream_assignment`

Assignment record for participants attached to a workstream post.

Fields:
- `id`
- `workstream_post_id`
- `post_participant_id`
- `assignment_role`
  - `owner`
  - `contributor`
  - `reviewer`
  - `executor`
- `created_at`
- `completed_at` nullable

Purpose:
- workstream-specific role assignment layered on top of the base post roster

---

### 9.4 Activation And Runs

This section models runtime linkage to activation and execution records.
Authoritative activation semantics, trace requirements, and contract resolution
rules belong to RFC-0001.

RFC-0002 intentionally models activation linkage and runtime relationships only.
It does not redefine contract semantics, precedence rules, or trace policy.

#### `persona_activation`

Runtime linkage record for an activation resolved under RFC-0001.

Fields:
- `id`
- `initiated_by_participant_type`
  - `user`
  - `workspace_persona`
  - `system`
- `initiated_by_participant_id`
- `workspace_id`
- `channel_id` nullable
- `origin_post_id`
- `origin_thread_id`
- `trigger_message_id`
- `addressed_target_kind`
  - `collaborator`
  - `team`
  - `squad`
- `addressed_target_reference_id`
- `resolved_workspace_persona_instance_id`
- `response_mode`
- `created_at`

Purpose:
- ties contract-resolution output to concrete runtime collaboration context

---

#### `agent_run`

Execution run linked to one activation.

Fields:
- `id`
- `persona_activation_id`
- `runner_kind`
- `status`
  - `queued`
  - `running`
  - `completed`
  - `failed`
  - `cancelled`
- `started_at`
- `completed_at` nullable
- `failure_reason` nullable

Purpose:
- boundary between resolved activation and execution runtime

---

#### `agent_run_step`

Optional low-level trace step within a run.

Fields:
- `id`
- `agent_run_id`
- `step_type`
  - `contract_resolution_snapshot`
  - `memory_retrieval`
  - `runner_call`
  - `tool_use`
  - `postprocess`
- `payload`
- `created_at`

Purpose:
- structured debugging and deep traceability

---

#### `activation_memory_source`

Join record describing which approved memory influenced an activation.

Fields:
- `id`
- `persona_activation_id`
- `memory_entry_id`
- `source_order`
- `retrieval_reason`

Purpose:
- explainability
- later memory quality evaluation

---

### 9.5 Journaling

#### `journal_entry`

Reflective artifact produced from lived post and thread activity.

Fields:
- `id`
- `workspace_id`
- `workspace_persona_id` nullable
- `source_post_id` nullable
- `source_thread_id` nullable
- `entry_type`
  - `daily`
  - `meeting`
  - `milestone`
  - `design_rationale`
  - `technical_notes`
  - `manual`
- `time_window_start`
- `time_window_end`
- `body`
- `created_at`

Purpose:
- compression layer between raw post activity and durable memory

---

#### `journal_source`

Lineage from journal to source artifacts.

Fields:
- `id`
- `journal_entry_id`
- `source_type`
  - `post`
  - `thread`
  - `message`
  - `post_event`
  - `run`
  - `note`
  - `decision`
  - `manual`
- `source_id`

Purpose:
- allows journals to cite what they summarize

---

### 9.6 Memory

#### `memory_candidate`

Proposed memory derived from journals or runtime artifacts.

Fields:
- `id`
- `workspace_id` nullable
- `workspace_persona_id` nullable
- `persona_template_id` nullable
- `source_type`
  - `journal`
  - `post`
  - `thread`
  - `message`
  - `run`
  - `note`
  - `decision`
  - `manual`
- `source_id`
- `proposed_scope`
  - `workspace`
  - `workspace_persona`
  - `persona_global`
  - `organization`
- `title`
- `body`
- `confidence`
- `status`
  - `candidate`
  - `approved`
  - `rejected`
  - `archived`
  - `deferred`
- `created_at`
- `reviewed_at` nullable

Purpose:
- explicit staging area between reflection and durable memory

Note:
- v1 does not establish team-scoped memory as a first-class scope
- if team-level relevance matters, it should be represented through tagged or
  linked workspace memory rather than a separate scope
- raw source types such as `post`, `thread`, `message`, and `run` exist to
  support explicit policy-governed or operator-directed exceptions; journals and
  structured artifacts remain the normal candidate sources

---

#### `memory_review`

Review action taken by the operator or steward process.

Fields:
- `id`
- `memory_candidate_id`
- `reviewer_type`
  - `operator`
  - `steward`
  - `system`
- `reviewer_id`
- `decision`
  - `approve`
  - `reject`
  - `archive`
  - `defer`
- `notes` nullable
- `created_at`

Purpose:
- makes memory governance explicit

---

#### `memory_entry`

Approved durable memory.

Fields:
- `id`
- `scope`
  - `workspace`
  - `workspace_persona`
  - `persona_global`
  - `organization`
- `workspace_id` nullable
- `workspace_persona_id` nullable
- `persona_template_id` nullable
- `title`
- `body`
- `status`
  - `active`
  - `archived`
  - `superseded`
  - `expired`
- `valid_from`
- `valid_to` nullable
- `source_memory_candidate_id` nullable
- `created_at`

Purpose:
- durable memory eligible for future activation retrieval

---

#### `memory_link`

Traversal and lineage relationship between memory entries.

Fields:
- `id`
- `from_memory_entry_id`
- `to_memory_entry_id`
- `link_type`
  - `derived_from`
  - `reinforces`
  - `contradicts`
  - `supersedes`
  - `related_workspace`
  - `same_pattern_as`
  - `topic_link`
  - `triggered_by`
- `created_at`

Purpose:
- enables graph-like traversal while staying relational

---

#### `persona_global_memory_profile`

Profile of durable cross-workspace learning for a persona template.

Fields:
- `id`
- `persona_template_id`
- `summary`
- `last_curated_at`
- `created_at`

Purpose:
- separates authored persona identity from accumulated durable expertise

---

### 9.7 Attached Structured Objects

Attached structured objects remain post-linked by default rather than becoming
first-class post types in v1.

#### `note`

Structured note attached to a post.

Fields:
- `id`
- `post_id`
- `note_type`
  - `brief`
  - `detailed`
  - `meeting_summary`
  - `retrospective`
  - `workstream_closeout`
  - `manual`
- `body`
- `created_by_participant_type`
  - `user`
  - `workspace_persona`
  - `system`
- `created_by_participant_id`
- `created_at`

Purpose:
- captures summaries, reflective notes, and other durable text artifacts tied to
  a post

---

#### `decision`

Structured decision record attached to a post.

Fields:
- `id`
- `post_id`
- `title`
- `body`
- `decision_state`
  - `proposed`
  - `adopted`
  - `rejected`
  - `superseded`
- `rationale_note_id` nullable
- `created_at`

Purpose:
- captures committed or rejected choices with rationale and status

---

#### `reference`

Structured external or internal reference attached to a post.

Fields:
- `id`
- `post_id`
- `reference_type`
  - `url`
  - `doc`
  - `file`
  - `issue`
  - `commit`
  - `external_note`
- `target`
- `title` nullable
- `created_at`

Purpose:
- keeps supporting context linked to collaboration without hiding it in message
  bodies

---

#### `artifact`

Structured artifact record attached to a post.

Fields:
- `id`
- `post_id`
- `artifact_type`
  - `file`
  - `image`
  - `code_output`
  - `report`
  - `bundle`
  - `other`
- `storage_ref`
- `title` nullable
- `created_at`

Purpose:
- tracks durable outputs produced by meeting or workstream activity

---

## 10. UX / Product Implications

This data model implies several product truths.

### 10.1 Channels surface posts, not just messages

The main list view should be able to show:

- message posts
- meeting posts
- workstream posts
- post status and type
- linked follow-up work

### 10.2 Threads are attached to posts

The UI should make it obvious that replies belong to a post's thread, not to a
global room-wide log.

### 10.3 Meeting and workstream posts are first-class

Orbit should be able to show:

- why a discussion was promoted into a meeting post
- which workstream post was launched from which origin post
- status, participants, and outputs for those linked posts

### 10.4 Structured objects should be inspectable

The UI should support attached:

- notes
- decisions
- references
- artifacts

without forcing all of that meaning into thread messages.

### 10.5 Memory must be visible and governable

The operator should be able to:

- inspect candidate memory
- approve or reject it
- view memory lineage
- inspect which memories influenced an activation

### 10.6 Multi-client consistency matters

Because macOS, iPhone, and iPad clients will all read this system, the model
must support:

- realtime updates
- replay
- offline reconciliation later
- state reconstruction from persisted records

---

## 11. Edge Cases And Failure Modes

### 11.1 Database write fails for a message post or reply

- No coordination should begin
- No activation should be created
- Client should keep local draft if possible
- Error must be surfaced clearly

### 11.2 Post event persistence fails after message persistence

- Message remains durable
- Orbit should retry event persistence where possible
- Trace views may show temporary incompleteness

### 11.3 Meeting promotion fails after thread activity persists

- The originating post and thread remain durable
- Promotion failure is recorded as a post event
- The operator may retry promotion

### 11.4 Workstream post creation partially succeeds

- The origin post remains durable
- Partial creation must not produce an unlinked orphan post silently
- Failure or partial linkage must be visible

### 11.5 One collaborator fails while others complete

- Successful responses still render in the thread
- Failure is visible as a post event or run status
- Meeting or workstream posts may still summarize partial results

### 11.6 Structured object attachment fails

- The post remains valid without the object
- Failure is recorded explicitly
- The operator may retry attachment or creation

### 11.7 Memory candidate conflicts with approved memory

- Candidate should not auto-promote
- Review should surface contradiction
- Memory linkage should support `contradicts` or `supersedes`

### 11.8 Template or directive changes mid-thread

- Activation should record the version references used
- Existing messages remain attributable to prior activation context
- Later activations may use newer definitions

### 11.9 Offline mobile client

- Draft posts or messages may queue locally
- Server-side ordering remains the source of truth once synced
- Client should not fabricate activations locally

### 11.10 Archived or stale memory in retrieval

- Retrieval should ignore archived or expired memory
- Activation trace should record omission where relevant
- No silent fallback to untrusted memory blobs

### 11.11 Broken or missing post link

- Post and thread history remain durable even if a linked post is missing
- UI should surface broken continuity rather than pretending linkage is intact

---

## 12. Alternatives Considered

### Alternative A: Store everything as message history only

Rejected because:

- message history is too noisy to carry meetings, workstreams, and memory
- structured objects become hard to govern
- traceability becomes weak

### Alternative B: Keep `conversation` as the primary root object

Rejected because Orbit's product model is now post-first, not conversation-first.

### Alternative C: Make meetings and workstreams separate root entities

Rejected because that would weaken continuity with the message post and thread
that produced them.

### Alternative D: Treat summaries as the only structured attachment

Rejected because Orbit needs multiple attached object types, not a single summary
bucket.

### Alternative E: Introduce team-scoped memory in v1

Rejected for now because the current product vision does not require a separate
first-class team memory scope. Tagged or linked workspace memory is sufficient
initially.

### Alternative F: Pure graph database from day one

Rejected for now because a relational model is sufficient initially, while
`memory_link` and `post_link` can provide graph-like traversal where needed.

### Alternative G: Directly mutate persona definitions as they learn

Rejected because it destroys authored identity clarity and weakens explainable
contract resolution.

---

## 13. Risks And Tradeoffs

### Risk: Model complexity

This RFC introduces many entities.

Tradeoff:
- the product itself is structurally complex
- collapsing entities would make the system less legible, not more

### Risk: Structured object sprawl

Notes, decisions, references, and artifacts may proliferate if created without
discipline.

Tradeoff:
- explicit object types make governance and UI presentation easier than hiding
  everything in messages

### Risk: Memory sprawl

If journals and memory candidates are generated too aggressively, the system will
accumulate noise.

Tradeoff:
- the staged candidate/review/approved model is intended to control this

### Risk: Query complexity

Post links, activation links, and scoped memory retrieval all increase query
complexity.

Tradeoff:
- this is preferable to a flatter model that loses traceability and context

### Risk: User-facing overload

If Orbit exposes all artifacts equally, users may feel overwhelmed.

Tradeoff:
- the data model should support rich inspection even if the initial UI presents a
  simpler slice of it

---

## 14. Open Questions

- Should `channel_id` remain required on every post in v1, or should some post
  types support channel-null contexts later?
- Should `meeting_member` and `workstream_assignment` eventually share a common
  extension model over `post_participant`?
- Should notes, decisions, references, and artifacts eventually share a common
  typed base record?
- How much `agent_run_step` detail is worth storing long-term?
- Should notes or decisions ever be promotable into first-class post types in a
  later version?
- Should organization-scoped memory exist in all deployments, or remain optional
  in smaller self-hosted setups?

---

## 15. Recommendation

Adopt this RFC as the conceptual runtime model direction for Orbit's
collaboration runtime and memory system.

Specifically:

- keep authored definitions file-backed in PersonaKit
- store runtime collaboration state in a relational database
- treat posts, threads, messages, structured objects, journals, memory
  candidates, and memory entries as distinct artifacts
- model meetings and workstreams as post-based runtime objects
- preserve memory scope and lineage explicitly
- defer exact SQL schema and API details to implementation design

This is the strongest foundation for Orbit's current product direction:

- workspaces
- channels
- teams and squads
- posts and threads
- meeting and workstream promotion
- durable memory
- multi-client self-hosted operation

---

## 16. Rollout / Adoption Plan

### Phase 1

Introduce the minimum viable collaboration runtime:

- workspace
- channel
- workspace_persona
- post
- thread
- message
- post_participant
- post_event
- post_link
- persona_activation
- agent_run

Goal:
- durable multi-client post/thread collaboration with activation attribution

### Phase 2

Add meeting and workstream runtime state:

- meeting_state
- meeting_member
- workstream_state
- workstream_assignment

Goal:
- promoted meetings and linked execution work with visible lifecycle state

### Phase 3

Add attached structured objects:

- note
- decision
- reference
- artifact

Goal:
- durable non-message collaboration outputs attached to posts

### Phase 4

Add journals and candidate memory:

- journal_entry
- journal_source
- memory_candidate
- memory_review

Goal:
- reflective compression and reviewed memory growth

### Phase 5

Add approved memory and deeper retrieval:

- memory_entry
- memory_link
- persona_global_memory_profile
- activation_memory_source

Goal:
- long-term collaborator expertise, lineage, and explainable retrieval

---

## 17. Self-Review

- Does this model preserve operator authority over durable memory?
  Yes.

- Does it distinguish authored contract truth from runtime collaboration state?
  Yes.

- Does it match Orbit's post/thread/meeting/workstream model?
  Yes.

- Does it give implementation enough structure without prematurely locking the
  final schema?
  Yes.

- Does it keep activation semantics primarily owned by RFC-0001?
  Yes.

- Are failure modes and lifecycle stages explicit enough to keep the product
  legible?
  Mostly yes; channel semantics and some structured-object details may need
  follow-up refinement.

---

## 18. Decision Log

- 2026-03-08 - Initial draft created as RFC proposal
- 2026-03-17 - Rewritten to align with Orbit's post/thread runtime model,
  RFC-0001 contract-resolution ownership, post-linked meeting and workstream
  state, attached structured objects, and reviewed-memory scope rules
- 2026-03-17 - Removed duplicate appended draft and consolidated the RFC into a
  single canonical document
