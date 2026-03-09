# RFC-0002: Conversation and Memory Data Model

## Status
Draft

## Authors
- AJ Self
- ChatGPT / ProdDoc

## Created
2026-03-08

## Last Updated
2026-03-08

## Related
- RFC-0001: Persona Activation and Default Directive Model
- AGENTS.md
- README.md
- Docs/RFCs/README.md

---

## 1. Summary

This RFC proposes the **core data model** for PersonaKit’s conversation, meeting, journaling, and memory systems.

The purpose of this model is to support PersonaKit’s evolution into a **workspace-centric command center for AI teams**, where:

- one human interacts with many personas
- personas operate within workspaces, teams, and squads
- conversations are durable and replayable
- memory is proposed, reviewed, approved, and retrieved
- persona identity and grounding remain explicit and attributable

This RFC defines the conceptual entities, relationships, scopes, and lifecycle rules needed to make that system implementable.

It does **not** lock the final database schema or API. It proposes the data shape that future implementation should follow.

---

## 2. Motivation

PersonaKit is moving beyond local prompt grounding into a system for:

- persistent team chat
- meeting-style collaboration
- persona memory
- cross-workspace learning
- realtime multi-device interaction
- long-term organizational knowledge

The current local/file-centric model is well suited to authored definitions, but it is not a sufficient model for:

- storing message history
- querying prior discussions
- reconstructing meeting flows
- attributing agent runs
- reviewing memory candidates
- promoting durable knowledge
- analyzing patterns across time

If PersonaKit is going to become the command center for an incubator of AI teams, it needs a **durable interaction model** and a **memory model** that are explicit from the start.

This RFC exists to define that foundation before implementation sprawls.

---

## 3. Problem Statement

PersonaKit needs a data model that can answer all of the following reliably:

- What conversations happened in a workspace?
- Who participated in a given meeting or thread?
- Which persona said a given thing, under which directive?
- Which memories influenced that response?
- Which journal entries were created from that interaction?
- Which memory candidates were proposed?
- Which candidate memories were approved, rejected, archived, or superseded?
- Which durable memories belong to a workspace, a persona instance, or a global persona memory profile?
- How can future activations retrieve the right memory without cross-workspace contamination?

At present, PersonaKit has strong authored identity and grounding concepts, but no agreed system-wide model for:

- conversations
- events
- journaling
- candidate memory
- approved memory
- memory linkage
- attribution and replay

The system needs a model that is:

- relational
- inspectable
- evolvable
- safe for memory growth
- compatible with realtime UX
- compatible with later analytics and search

---

## 4. Goals

This RFC aims to establish a data model that:

- supports durable, replayable conversations
- treats messages and system events as distinct artifacts
- supports meetings, teams, and squads as first-class concepts
- records persona activation and run attribution explicitly
- supports journaling as a first-class reflection layer
- supports memory candidates and approved memory as distinct stages
- enables scoped memory retrieval:
  - workspace
  - workspace persona
  - global persona profile
  - organization
- supports explicit traversal and lineage between memories
- supports future analytics, summaries, and search
- preserves PersonaKit’s principles:
  - explicit over inferred
  - structure over autonomy
  - humans in control

---

## 5. Non-Goals

This RFC does **not** attempt to define:

- the exact SQL schema or migration files
- the final API endpoints
- the final client sync protocol
- the final authentication model
- the final search or vector indexing implementation
- the exact UI for chat, memory review, or meetings
- provider-specific run payloads for Codex/OpenAI/GitHub
- cost optimization or sharding strategy

Those should be addressed in later RFCs or implementation docs.

---

## 6. Proposal

This RFC proposes that PersonaKit’s runtime data be modeled around **five major domains**:

1. **Workspace Structure**
2. **Conversation and Meeting State**
3. **Persona Activation and Runs**
4. **Journaling**
5. **Memory**

These domains should be represented separately but linked through stable identifiers.

### High-level proposal

- Authored definitions remain file-backed in PersonaKit definitions.
- Runtime collaboration and memory are stored durably in a database.
- Messages, events, journals, memory candidates, and memory entries are separate records.
- Memory is never just “more chat history.”
- Memory requires:
  - staging
  - review
  - attribution
  - scope
  - lineage

### Core design law

> Files define who the team is.  
> Database records what the team has done and what it should remember.

---

## 7. Architecture / System Design

### 7.1 Runtime domains

```text
Workspace
  ├── Teams / Squads
  ├── Conversations
  │    ├── Messages
  │    ├── Events
  │    └── Participants
  ├── Meetings
  ├── Persona Activations
  ├── Agent Runs
  ├── Journals
  ├── Memory Candidates
  └── Memory Entries
```

### 7.2 Sequence model

```text
User sends message
  ↓
ConversationMessage persisted
  ↓
ConversationEvent emitted
  ↓
Meeting Coordinator selects participants
  ↓
PersonaActivation records created
  ↓
AgentRun records created
  ↓
Persona responses persisted as ConversationMessages
  ↓
Journal entries optionally generated
  ↓
Memory candidates proposed
  ↓
Human review
  ↓
Approved MemoryEntry created
```

### 7.3 Important separation

This RFC makes a hard distinction between:

- **Message** — conversational content visible in chat
- **Event** — system state transition or operational fact
- **Journal** — reflective compression of activity
- **Memory Candidate** — proposed durable learning
- **Memory Entry** — approved durable memory

That separation is essential.

---

## 8. Data Model

This section defines the proposed entities and relationships.

### 8.1 Workspace Structure

#### `workspace`
Top-level container for a venture, product, research stream, or internal initiative.

Fields:
- `id`
- `slug`
- `name`
- `status`
- `created_at`
- `archived_at` nullable

Purpose:
- scopes conversations
- scopes teams and squads
- scopes local memory
- scopes workspace persona instances

---

#### `team`
Durable group of personas in a workspace.

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
- supports “wear the Bar product team”
- enables coordinator-based participant expansion

---

#### `workspace_persona`
Instance of a global persona inside a workspace.

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
- participant in meetings and conversations
- carrier of workspace-local expertise

---

#### `workspace_persona_membership`
Links workspace personas to teams and squads.

Fields:
- `id`
- `workspace_persona_id`
- `team_id` nullable
- `squad_id` nullable
- `role_in_group`
- `created_at`

---

### 8.2 Conversation and Meeting State

#### `conversation`
A durable discussion thread.

Fields:
- `id`
- `workspace_id`
- `title` nullable
- `conversation_type`
  - direct
  - team
  - squad
  - meeting
  - research
- `status`
  - open
  - paused
  - completed
  - archived
- `created_by_user_id`
- `created_at`
- `closed_at` nullable

Purpose:
- top-level container for chat history
- basis for summaries and memory extraction

---

#### `conversation_participant`
Roster membership in a conversation.

Fields:
- `id`
- `conversation_id`
- `participant_type`
  - user
  - workspace_persona
  - system
- `participant_id`
- `joined_at`
- `left_at` nullable
- `participation_mode`
  - active
  - observing
  - invited
  - coordinator-managed

Purpose:
- determines who is in the room
- allows explicit presence and absence

---

#### `conversation_message`
Visible chat artifact.

Fields:
- `id`
- `conversation_id`
- `author_type`
  - user
  - workspace_persona
  - system
- `author_id`
- `reply_to_message_id` nullable
- `body`
- `message_format`
  - plain_text
  - markdown
  - structured
- `state`
  - drafted
  - persisted
  - routed
  - in_progress
  - completed
  - failed
  - superseded
- `visible_to_user`
- `created_at`
- `updated_at`

Purpose:
- everything the user sees as “chat bubbles”
- durable user and persona utterances

---

#### `conversation_event`
Operational system event.

Fields:
- `id`
- `conversation_id`
- `event_type`
- `payload`
- `created_at`

Examples:
- coordinator.selected_participants
- persona.run_started
- persona.run_failed
- summary.created
- memory.candidate_created
- memory.approved

Purpose:
- system trace
- UI status reconstruction
- debugging and analytics

---

#### `meeting`
Structured conversation event with coordination semantics.

Fields:
- `id`
- `workspace_id`
- `conversation_id`
- `meeting_type`
  - ad_hoc
  - squad
  - team
  - review
  - planning
  - retrospective
- `started_by_user_id`
- `status`
  - created
  - active
  - summarizing
  - completed
  - failed
- `started_at`
- `completed_at` nullable

Purpose:
- support “team chat as meeting”
- attach summaries and journals cleanly

---

#### `meeting_member`
Explicit participant record for a meeting.

Fields:
- `id`
- `meeting_id`
- `workspace_persona_id`
- `participation_role`
  - facilitator
  - contributor
  - observer
  - summarizer
- `selected_reason`
- `joined_at`
- `completed_at` nullable

---

### 8.3 Persona Activation and Runs

#### `persona_activation`
Durable record of a persona entering a conversation.

Fields:
- `id`
- `workspace_id`
- `conversation_id`
- `meeting_id` nullable
- `workspace_persona_id`
- `directive_id`
- `activation_reason`
- `trigger_message_id`
- `template_version`
- `created_at`

Purpose:
- explain why a persona responded
- capture the exact grounding entry point

---

#### `agent_run`
One invocation of a model/provider for a persona activation.

Fields:
- `id`
- `persona_activation_id`
- `provider`
- `model_name`
- `status`
  - queued
  - running
  - completed
  - failed
  - cancelled
- `started_at`
- `completed_at` nullable
- `failure_reason` nullable

Purpose:
- stable attribution boundary between PersonaKit and provider calls

---

#### `agent_run_step`
Optional trace step within a run.

Fields:
- `id`
- `agent_run_id`
- `step_type`
  - grounding
  - retrieval
  - provider_call
  - tool_use
  - postprocess
  - summary
- `payload`
- `created_at`

Purpose:
- structured traceability
- later debugging and analytics

---

#### `agent_run_memory_source`
Join table recording which memory influenced a run.

Fields:
- `id`
- `agent_run_id`
- `memory_entry_id`
- `source_order`
- `retrieval_reason`

Purpose:
- explainability
- later memory quality evaluation

---

### 8.4 Journaling

#### `journal_entry`
Reflective artifact produced from lived activity.

Fields:
- `id`
- `workspace_id`
- `workspace_persona_id`
- `conversation_id` nullable
- `meeting_id` nullable
- `entry_type`
  - daily
  - meeting
  - milestone
  - design_rationale
  - technical_notes
  - manual
- `time_window_start`
- `time_window_end`
- `body`
- `created_at`

Purpose:
- compression layer between raw conversation and durable memory
- supports Rosie / gardening workflows

---

#### `journal_source`
Optional lineage from journal to source artifacts.

Fields:
- `id`
- `journal_entry_id`
- `source_type`
  - message
  - event
  - run
  - summary
- `source_id`

Purpose:
- allows journals to cite what they summarize

---

### 8.5 Memory

#### `memory_candidate`
Proposed memory derived from journals, meetings, or analysis.

Fields:
- `id`
- `workspace_id` nullable
- `workspace_persona_id` nullable
- `persona_template_id` nullable
- `source_type`
  - journal
  - meeting
  - conversation
  - run
  - manual
- `source_id`
- `proposed_scope`
  - workspace
  - workspace_persona
  - persona_global
  - team
  - organization
- `title`
- `body`
- `confidence`
- `status`
  - candidate
  - approved
  - rejected
  - archived
- `created_at`
- `reviewed_at` nullable

Purpose:
- explicit staging area between reflection and durable memory

---

#### `memory_review`
Review action taken by the human or steward process.

Fields:
- `id`
- `memory_candidate_id`
- `reviewer_type`
  - user
  - steward
  - system
- `reviewer_id`
- `decision`
  - approve
  - reject
  - archive
  - defer
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
  - workspace
  - workspace_persona
  - persona_global
  - team
  - organization
- `workspace_id` nullable
- `workspace_persona_id` nullable
- `persona_template_id` nullable
- `team_id` nullable
- `title`
- `body`
- `status`
  - active
  - archived
  - superseded
- `valid_from`
- `valid_to` nullable
- `source_memory_candidate_id` nullable
- `created_at`

Purpose:
- memory that can actually be retrieved during activation

---

#### `memory_link`
Traversal and lineage relationship between memory entries.

Fields:
- `id`
- `from_memory_entry_id`
- `to_memory_entry_id`
- `link_type`
  - derived_from
  - reinforces
  - contradicts
  - supersedes
  - related_workspace
  - same_pattern_as
  - topic_link
  - triggered_by
- `created_at`

Purpose:
- supports “I remember something related from Foo workspace around Bar time”
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

### 8.6 Summaries

#### `conversation_summary`
Summary artifact for a conversation or meeting.

Fields:
- `id`
- `workspace_id`
- `conversation_id`
- `meeting_id` nullable
- `summary_type`
  - brief
  - detailed
  - decision_log
  - retrospective
- `body`
- `created_at`

Purpose:
- direct user utility
- source material for journals and memory candidates

---

## 9. UX / Product Implications

This data model implies several product truths.

### 9.1 Chat is not “just messages”
The UI should distinguish:
- visible messages
- system events
- journals
- memory review actions

A simple bubble stream is not enough for all surfaces.

### 9.2 Meetings are first-class
The app should be able to show:
- who was invited
- why they were invited
- who responded
- who failed to respond
- what summary and memory candidates resulted

### 9.3 Memory must be visible and governable
The user should be able to:
- inspect candidate memory
- approve or reject it
- view memory lineage
- inspect which memories influenced a response

### 9.4 Journals are important UX artifacts
Journals are not just backend artifacts. They may become:
- timeline views
- weekly persona reflections
- project learning summaries

### 9.5 Multi-device consistency matters
Because macOS, iPhone, and iPad clients will all read this system, the model must support:
- realtime updates
- replay
- offline reconciliation later
- state reconstruction from persisted records

---

## 10. Edge Cases and Failure Modes

### 10.1 Database write fails for a user message
- No coordination should begin
- No activation should be created
- Client should keep local draft if possible
- Error must be surfaced clearly

### 10.2 Coordinator fails after message persistence
- Message remains durable
- Conversation event records failure
- User may retry routing

### 10.3 One persona fails while others complete
- Successful responses still render
- Failure is visible as an event/state
- Meeting may still summarize partial results

### 10.4 Memory candidate conflicts with approved memory
- Candidate should not auto-promote
- Review should surface contradiction
- Linkage should allow `contradicts` or `supersedes`

### 10.5 Persona template changes mid-conversation
- Activation should record template version used
- Existing messages remain attributable to the prior version
- Later activations may use the newer version

### 10.6 Same lesson appears in many workspaces
- Memory candidates may be separate at first
- Rosie/gardening or human review may promote a cross-workspace memory
- Memory links should preserve source lineage

### 10.7 Offline mobile client
- Draft messages may queue locally
- Server-side ordering remains source of truth once synced
- Client should not fabricate activations locally

### 10.8 Stale or archived memory in retrieval
- Retrieval should ignore archived or expired memory
- Run trace should record omission where relevant
- No silent fallback to untrusted memory blobs

---

## 11. Alternatives Considered

### Alternative A: Store everything as chat history only
Rejected because:
- chat history is too noisy for memory
- hard to govern
- poor attribution
- poor analytics value

### Alternative B: Treat summaries as memory
Rejected because:
- summaries are useful but not automatically durable knowledge
- they still need review and scope

### Alternative C: Directly mutate persona definitions as they learn
Rejected because:
- destroys authored identity clarity
- makes behavior opaque
- causes uncontrolled drift

### Alternative D: Workspace-local memory only
Rejected because:
- prevents durable cross-workspace expertise
- blocks the incubator-scale vision

### Alternative E: Global memory only
Rejected because:
- causes contamination
- makes local project context unsafe
- weakens explainability

### Alternative F: Pure graph database from day one
Rejected for now because:
- relational model is sufficient and simpler initially
- graph-like traversal can be modeled with `memory_link`
- premature complexity adds risk

---

## 12. Risks and Tradeoffs

### Risk: Model complexity
This RFC introduces many entities. That is real complexity.

Tradeoff:
- the product vision itself is structurally complex
- collapsing entities would make the system less legible, not more

### Risk: Memory sprawl
If journals and memory candidates are generated too aggressively, the system will accumulate noise.

Tradeoff:
- the staged candidate/review/approved model is intended to control this

### Risk: Over-modeling too early
There is a chance some entities will not be needed immediately.

Tradeoff:
- defining them now avoids accidental coupling and gives the roadmap a coherent shape

### Risk: Query complexity
Scoped retrieval across workspace, persona instance, and persona global memory adds complexity.

Tradeoff:
- this is preferable to unsafe global retrieval or duplicated persona models

### Risk: User-facing UX overload
If the app exposes all artifacts equally, users may feel overwhelmed.

Tradeoff:
- the data model should support rich inspection even if the initial UI stays simpler

---

## 13. Open Questions

- Should `journal_entry` be generated synchronously after meetings, or by background jobs only?
- Should memory candidates ever be auto-approved in narrow categories?
- Should team-scoped memory exist separately from workspace-scoped memory, or can it be modeled as tagged workspace memory initially?
- How much run-step trace detail is worth storing long-term?
- Should summaries be mutable, versioned, or append-only?
- Should conversation events use a strict typed enum model or a more flexible payload model first?
- Should mobile clients cache journals and memory locally, or only conversations?

---

## 14. Recommendation

Adopt this RFC as the **conceptual data model direction** for PersonaKit’s conversation and memory system.

Specifically:

- Keep authored definitions file-backed
- Store runtime collaboration state in a relational database
- Treat messages, events, journals, memory candidates, and memory entries as distinct artifacts
- Preserve memory scope and lineage explicitly
- Support both workspace-local learning and persona-global learning
- Defer exact SQL schema and API details to implementation design

This is the strongest foundation for the product direction you’ve described:
- workspaces
- teams
- squads
- meetings
- durable memory
- incubator-scale growth

---

## 15. Rollout / Adoption Plan

### Phase 1
Introduce the minimum viable runtime entities:
- workspace
- conversation
- conversation_message
- conversation_event
- workspace_persona
- persona_activation
- agent_run

Goal:
- durable multi-client chat with persona attribution

### Phase 2
Add structured meeting support:
- meeting
- meeting_member
- conversation_summary

Goal:
- team and squad collaboration with summaries

### Phase 3
Add journals and candidate memory:
- journal_entry
- memory_candidate
- memory_review

Goal:
- reflective compression and reviewed memory growth

### Phase 4
Add durable memory and traversal:
- memory_entry
- memory_link
- persona_global_memory_profile

Goal:
- long-term persona expertise and cross-workspace learning

### Phase 5
Add analytics and advanced retrieval
Goal:
- search, trend analysis, memory quality scoring, and deeper operational insights

---

## 16. Self-Review

- Does this model preserve human authority over durable memory?  
  Yes.

- Does it distinguish authored identity from learned memory?  
  Yes.

- Does it support workspace-local and cross-workspace learning without flattening them together?  
  Yes.

- Does it give future implementations enough structure without prematurely locking the final schema?  
  Yes.

- Are failure modes and lifecycle stages explicit enough to keep the product legible?  
  Mostly yes; meeting lifecycle and mobile sync may need deeper follow-up RFCs.

- Does it preserve PersonaKit’s core values of explicitness, determinism, and human control?  
  Yes.

---

## 17. Decision Log

- 2026-03-08 — Initial draft created as RFC proposal
- 2026-03-08 — Positioned as companion to RFC-0001 activation model

---

If you want, the next best move is to draft **RFC-0003: Workspace and Persona Instance Model**, because that will lock the top-level identity and tenancy model that everything else hangs off. That aligns with the RFC roadmap you already captured in Sources. fileciteturn14file0
# RFC-0002: Conversation and Memory Data Model

## Status
Draft

## Authors
- AJ Self
- ChatGPT / ProdDoc

## Created
2026-03-08

## Last Updated
2026-03-08

## Related
- RFC-0001 – Persona Activation and Default Directive Model
- RFC-0003 – Workspace and Persona Instance Model
- RFC-0004 – Teams, Squads, and Meeting Coordinator Model
- RFC-0005 – Memory Journaling and Gardening Model

---

## 1. Summary

This RFC defines the conceptual data model for Orbit’s conversation, meeting, journaling, and memory systems.

Orbit is designed as a workspace-centric platform where:

- a human operates multiple workspaces
- personas collaborate through conversations and meetings
- conversations are durable and replayable
- memory is proposed, reviewed, approved, and retrieved
- every response remains attributable and inspectable

This RFC does **not** define the final SQL schema or API surface. It defines the conceptual structure that future implementation should follow.

---

## 2. Motivation

Orbit is not just a chat application. It is a platform for running persistent AI teams.

That means the system must support much more than transient message exchange. It must support:

- durable conversations
- meeting participation and coordination
- persona activation and run attribution
- reflective journaling
- reviewed memory growth
- cross-workspace learning without contamination

The authored-definition model is appropriate for persona templates, directives, and other static definitions, but it is not sufficient for runtime collaboration state.

Without a clear data model, Orbit risks:

- fragmented conversation history
- weak traceability
- ambiguous meeting state
- noisy or unsafe memory growth
- inconsistent client behavior across macOS, iPhone, and iPad

This RFC exists to define the durable runtime model before implementation spreads across clients and services.

---

## 3. Problem Statement

Orbit needs a data model that can answer all of the following questions reliably:

- What conversations happened in a workspace?
- Who participated in a given conversation or meeting?
- Which persona said a given thing, under which directive?
- Which memories influenced that response?
- Which journals were created from that activity?
- Which memory candidates were proposed?
- Which candidates were approved, rejected, archived, or superseded?
- Which durable memories belong to a workspace, a workspace persona, or a persona global memory profile?
- How can future activations retrieve the right knowledge without cross-workspace contamination?

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

- supports durable, replayable conversations
- treats messages and system events as distinct artifacts
- supports meetings, teams, and squads as first-class concepts
- records persona activation and run attribution explicitly
- supports journaling as a first-class reflection layer
- supports memory candidates and approved memory as distinct stages
- enables scoped retrieval for:
  - workspace
  - workspace persona
  - persona global memory
  - team
  - organization
- supports lineage and traversal between durable memories
- supports future analytics, summaries, and search

---

## 5. Non-Goals

This RFC does **not** define:

- the final SQL schema or migrations
- the final API endpoints
- the final client sync protocol
- the final authentication model
- the final vector indexing or search ranking implementation
- the exact UI for chat, memory review, or meetings

---

## 6. Proposal

Orbit’s runtime data should be modeled around five major domains:

1. Workspace structure
2. Conversation and meeting state
3. Persona activation and runs
4. Journaling
5. Memory

These domains should remain separate but linked through stable identifiers.

### Core Design Law

> Files define who the team is.  
> The database records what the team has done and what it should remember.

---

## 7. Runtime Domains

```text
Workspace
  ├── Teams / Squads
  ├── Conversations
  │    ├── Messages
  │    ├── Events
  │    └── Participants
  ├── Meetings
  ├── Persona Activations
  ├── Agent Runs
  ├── Journals
  ├── Memory Candidates
  └── Memory Entries
```

---

## 8. Data Model

### workspace
Top-level container for a venture or project.

### team
Durable group of personas in a workspace.

### squad
Focused working group within a workspace.

### workspace_persona
Instance of a persona template inside a workspace.

### conversation
A durable discussion thread.

### conversation_message
Visible chat artifact authored by a user or persona.

### conversation_event
Operational system event for coordination and tracing.

### meeting
Structured collaborative interaction attached to a conversation.

### meeting_member
Participant record for a meeting.

### persona_activation
Record of a persona entering a conversation.

### agent_run
Execution of a model provider for a persona activation.

### journal_entry
Reflective artifact summarizing activity over time.

### memory_candidate
Proposed durable learning derived from journals or meetings.

### memory_review
Governance action approving or rejecting a memory candidate.

### memory_entry
Approved durable memory that can influence future activations.

### memory_link
Relationship between memory entries for traversal and lineage.

### persona_global_memory_profile
Accumulated cross-workspace expertise for a persona template.

---

## 9. UX Implications

This model implies several product truths:

- chat is not just messages
- meetings are first-class collaborative objects
- memory must be visible and governable
- journals represent reflective learning

---

## 10. Recommendation

Adopt this RFC as the conceptual data model direction for Orbit’s conversation and memory system.

This structure provides the foundation for:

- workspace collaboration
- multi-persona meetings
- durable knowledge
- explainable AI reasoning

---

## 11. Decision Log

- 2026-03-08 — Initial draft created
- 2026-03-08 — Revised to align with Orbit platform terminology