# Orbit Platform Vision And System Design

Status: Draft
Owner: AJ
Last Reviewed: 2026-03-16

## Purpose

Pitch Orbit as a product worth building, define the roles and use cases that make
it distinct, and describe a system design that can run on self-hosted hardware
while staying aligned with PersonaKit.

## Why This Exists

Orbit needs a single document that answers all of the following in one place:

- what Orbit is
- who it is for
- how the core collaboration model works
- how the primary features tie together
- how PersonaKit, StandardAgents ideas, and Dmux should fit

This document is that bridge between product story and technical shape.

## The Pitch

Orbit is a native collaboration system for running AI teams.

One founder or indie developer should be able to operate multiple ventures,
products, and research initiatives using persistent AI collaborators.

PersonaKit gives each collaborator a constitution: identity, directives, kits,
guardrails, and stop points.

Orbit gives those collaborators a room: workspaces, channels, threads,
meetings, notes, decisions, artifacts, and durable memory.

The result is not "better chat with AI." The result is a command center where a
founder or indie developer can work with a persistent team of AI specialists,
see why they responded, coordinate them in groups, and turn conversations into
real progress.

Orbit should transform AI from a tool you prompt into a team you work with.

The long-term product promise is simple:

> Orbit should feel like Slack, Notion, and a mission-control console were
> designed from day one for human-led AI teams.

## Target User And Product Wedge

Orbit's initial wedge should be clear.

The first customer is not a large enterprise collaboration admin. The first
customer is a founder, indie developer, or tiny studio lead who wants the
leverage of a small AI team without giving up clarity, authorship, or control.

That means the initial truth Orbit must prove is narrower than the long-term
vision:

- one human at the center of operations
- multiple persistent AI collaborators with distinct roles
- one or more serious workspaces with durable history
- self-hosted operation on personal or studio-owned hardware

Over time, Orbit may expand to support small human teams collaborating with the
same AI roster. But the first product should be optimized for the single human
operator who needs a real command center, not a generic team chat clone.

## Product Vision

Orbit is chat-first, but not chat-only.

Unlike traditional AI tools that focus on a single conversational assistant,
Orbit is designed for collaboration between multiple specialized roles that can
operate together as a team.

The primary experience is a conversation space where:

- the active workspace is always obvious
- the roster of available collaborators is visible
- threaded discussion is the default way work accumulates
- meetings can be started without losing conversational continuity
- notes, decisions, references, and artifacts stay within reach
- execution traces are inspectable instead of hidden

The human remains the center of gravity.

AI collaborators do not replace the founder. They orbit around the founder and
assist with thinking, planning, design, engineering, research, and review.

The point of the system is not role-play. It is leverage. Different
collaborators should contribute different professional perspectives, debate
ideas in structured discussion, record decisions and lessons learned, and grow
expertise through memory and journaling.

Orbit does not exist to let agents run wild. It exists to make coordinated AI
collaboration legible, durable, and useful.

It is not simply a chat interface. It is a system for managing the roles,
discussions, and knowledge that emerge when AI collaborators work together over
time.

## What Orbit Is And Is Not

### Orbit is

- a collaboration product for persistent AI teams
- a command center for multi-workspace, multi-role operations
- a conversation and meeting system with durable memory
- a system that turns ad hoc prompting into structured teamwork
- a native-first experience, especially on macOS
- a self-hostable platform for indie-scale private infrastructure

### Orbit is not

- a single-assistant chat shell with persona skins
- a hidden-autonomy agent swarm
- a cloud-only enterprise control plane
- a replacement for PersonaKit's authored operating contract
- a terminal multiplexer product in disguise

## Conceptual Model

Orbit should preserve a simple collaboration hierarchy:

```text
Founder
  -> Orbit Platform
    -> Workspaces
      -> Teams / Squads
        -> Workspace Personas
```

Each layer adds structure that lets Orbit scale from a single useful exchange
to a coordinated operating system for AI collaborators working across many
projects.

## Terminology

Orbit should use a small, stable vocabulary.

- `collaborator`: the default user-facing term for an AI teammate in Orbit
- `workspace persona`: the runtime identity for a collaborator inside one
  workspace
- `participant`: a collaborator or human included in a thread or meeting
- `agent`: an implementation term for execution machinery, not the main
  user-facing noun

This matters because Orbit is trying to feel like collaboration software, not a
developer-only agent framework.

## Operating Model

Orbit works only if the operating model is legible.
Different collaborators should contribute different perspectives to the same
problem, and the user should always be able to tell what is a human actor, what
is a collaboration structure, and what is a system service.

### Human And AI Actors

#### Founder / Operator

The human authority.

Responsibilities:

- define workspaces and goals
- decide which teams and squads matter
- review decisions, notes, and memory promotions
- approve or reject consequential changes
- remain the final source of truth

#### Workspace Persona

A persistent collaborator operating inside a workspace.

Workspace personas are not ephemeral prompts. They maintain identity, context,
and evolving expertise within a workspace.

Over time they should build a deeper understanding of the founder's
preferences, the workspace's history, and the decisions that shaped the work.

Responsibilities:

- speak from a stable role
- follow a PersonaKit-resolved contract
- contribute to threads and meetings
- accumulate local history and scoped memory

### Collaboration Structures

#### Workspace

The durable operating boundary for a venture, product, or research stream.

Responsibilities:

- scope conversations
- scope teams and squads
- scope memory and artifacts
- prevent cross-project contamination

#### Team

A durable group of collaborators responsible for a broad function.

Teams provide organizational continuity inside a workspace.

Examples:

- Product Team
- Engineering Team
- Research Team

#### Squad

A focused working group created for an initiative or workstream.

Squads let smaller groups collaborate without involving every persona in every
discussion.

Examples:

- Launch Readiness Squad
- Architecture Review Squad
- Onboarding Squad

### Platform Services

#### Meeting Coordinator

The visible orchestration service for group collaboration.

Responsibilities:

- expand team or squad targets into actual participants
- sequence participation when a discussion becomes a meeting
- record why participants were included
- handle partial failures visibly
- produce summaries and follow-up actions

#### Memory Gardener

The review service that turns useful work into durable learning.

Responsibilities:

- turn activity into journal candidates
- propose memory candidates
- prevent low-signal chat from becoming permanent memory
- keep memory scoped, attributable, and reviewable

#### Workstream Runner

The execution service that handles concrete tasks outside the core discussion
surface.

Responsibilities:

- run research, synthesis, or implementation work
- stream progress back into Orbit
- attach artifacts to the originating thread
- keep execution lanes separate from collaboration history

## Primary Use Cases

### 1. Daily Command Center

AJ opens Orbit on macOS and sees the active workspace, the collaborator roster,
the most important open threads, and what needs attention now.

Outcome:

- Orbit feels like an operational room, not a chatbot.

### 2. Ask A Team, Not A Prompt

AJ asks the Product Team to review a feature direction. Orbit expands the team
into actual participants, records why they were selected, and shows attributed
responses in one thread.

Outcome:

- group collaboration becomes explicit and inspectable.

### 3. Spin Up A Focused Meeting

A thread turns into a short structured meeting with a facilitator, one or more
contributors, and a reviewer. The meeting produces a summary, action list, and
linked artifacts without leaving the workspace context.

Outcome:

- multi-persona discussion feels intentional instead of accidental.

### 4. Produce A Decision Packet

A product, engineering, and research squad debate options. Orbit turns the
meeting into a decision note with rationale, dissent, references, and follow-up
threads.

Outcome:

- important choices become durable, searchable, and reviewable.

### 5. Launch A Workstream From A Thread

A thread identifies concrete work: a code spike, a research sweep, a doc draft,
or a QA pass. Orbit launches a workstream, tracks status separately, and streams
results back into the thread.

Outcome:

- execution can fan out without collapsing the conversation model.

### 6. Turn Activity Into Memory Carefully

After a meaningful meeting, Orbit proposes journal entries and memory candidates.
AJ reviews them before anything becomes part of durable workspace knowledge.

Outcome:

- the system learns without turning every message into noise.

### 7. Operate Privately On Personal Hardware

An indie developer runs an Orbit Server on a Mac mini or similar machine,
connects a macOS client, and gets durable collaboration without depending on a
large-cloud control plane.

Outcome:

- Orbit stays viable for private, cost-conscious, founder-scale use.

### 8. Handle Disagreement, Failure, And Stop Points

A meeting includes conflicting recommendations, or a workstream reaches a review
gate it cannot pass automatically. Orbit shows the disagreement, the blocked
state, the triggering stop point, and the next required human decision.

Outcome:

- trust comes from visible control, not from pretending the system never fails.

## Experience Principles

### Chat-first, room-aware

Conversation is the main surface, but the room always matters: workspace,
participants, thread context, and active workstreams should never disappear.

### Explainable collaboration

Every meaningful response should be attributable to a workspace persona and a
resolved PersonaKit contract.

### Threads are the durable unit of work

Notes, decisions, meetings, artifacts, and follow-up work should attach to a
thread rather than scattering across unrelated surfaces.

### Meetings are a mode, not a separate universe

Orbit should let a thread escalate into a meeting and settle back into normal
discussion without forcing the user into a new mental model.

### Memory is curated, not automatic

The system should compress experience through journals and review, not through
indiscriminate accumulation.

### Local-first private cloud

Orbit should be able to run well on self-hosted personal hardware, with cloud
providers treated as optional capability sources rather than mandatory control
planes.

## Trust, Review, And Control

Orbit should make human control concrete, not rhetorical.

For any meaningful response, meeting, or workstream, the operator should be able
to inspect:

- which workspace persona responded
- which PersonaKit directive and kits were active
- which memory sources influenced the response
- which skills or tools were authorized
- which stop points or review gates apply
- whether delegated work is still running, blocked, failed, or complete
- how a journal or memory candidate was derived from prior activity

For high-consequence actions, Orbit should require an explicit human decision.
Examples include:

- memory promotion
- cross-workspace knowledge promotion
- consequential external actions
- workstream closeout when review gates are not satisfied

This is one of Orbit's core product differentiators. The user should not have to
trust hidden orchestration logic when the system can expose the path that led to
an outcome.

## System Design Overview

Orbit should be designed as a layered system where PersonaKit remains the policy
and identity engine.

```text
Human Operator
    |
    v
Orbit Client Apps
  - macOS command center
  - iPhone quick interaction
  - iPad meeting surface
    |
    v
Orbit Gateway + Realtime Layer
  - auth
  - REST / WebSocket / SSE
  - subscriptions
    |
    v
Orbit Collaboration Services
  - thread service
  - meeting coordinator
  - decision / notes service
  - journal and memory service
  - workstream broker
    |
    +------------------------------+
    |                              |
    v                              v
PersonaKit Resolver            Execution Runners
  - persona resolution           - message turns
  - directive resolution         - subthreads
  - skill authorization          - research / synthesis jobs
  - stop points                  - optional repo lanes
    |                              |
    +--------------+---------------+
                   |
                   v
           Persistence + Artifacts
         - relational database
         - event log
         - search index
         - file / object storage
         - backups
```

### Design law

> PersonaKit defines who may act and under what rules.
> Orbit decides where collaboration happens and how work is observed.

## Core Runtime Model

### 1. Authored Truth Vs Runtime Truth

Orbit should keep a hard separation between authored operating contracts and
runtime collaboration data.

#### PersonaKit authored truth

- personas
- directives
- kits
- sessions
- skill authorization
- operating constraints

#### Orbit runtime truth

- workspaces
- threads
- meetings
- participants
- messages
- events
- notes and decisions
- journals
- memory candidates and entries
- workstreams and artifacts

This keeps Orbit from becoming the authoring system for identity and keeps
PersonaKit from becoming the database for live collaboration.

### 2. Workspaces, Channels, Threads, Meetings

Orbit should model collaboration around a nested structure:

```text
Workspace
  -> Channels (optional but recommended)
    -> Threads
      -> Messages
      -> Notes
      -> Decisions
      -> References
      -> Meetings
      -> Workstreams
```

#### Workspace

Top-level boundary for product, venture, or research activity.

#### Channel or room

A stable place for a class of conversation, such as `general`, `product`,
`engineering`, `research`, or `launch-readiness`.

Channels are organizational surfaces, not a second source of truth. The durable
unit is still the thread. For an MVP, Orbit can model channels as named thread
collections inside a workspace rather than a full Slack-style permissions and
notification system.

#### Thread

The primary durable object in Orbit. A thread owns:

- message history
- participant roster
- meeting history
- attached artifacts
- linked notes and decisions
- journal and memory lineage
- workstream references

#### Meeting

A structured collaboration mode attached to a thread rather than a disconnected
object. Meetings add:

- explicit participant selection
- role metadata such as contributor, reviewer, facilitator, or observer
- sequencing and completion state
- meeting summary and follow-ups

### 3. Persona Activation And Response Execution

When a thread requires a response, Orbit should call PersonaKit to resolve the
active operating contract before the response runs.

Resolved activation includes:

- workspace persona instance
- directive
- kits
- allowed skills
- stop points
- memory scope
- handoff and review rules

Orbit should persist the activation metadata alongside the response so the user
can inspect why a response happened.

### 4. Journals, Memory, And Learning

Orbit should not treat chat history as memory.

The learning pipeline should be:

```text
Thread activity
  -> summary or reflection
  -> journal candidate
  -> memory candidate
  -> human review
  -> approved memory entry
```

Each step should preserve attribution and scope.

Memory scopes should include:

- workspace memory
- workspace persona memory
- global persona profile memory
- organization-level shared memory when explicitly promoted

### 5. Workstreams And Execution Lanes

Orbit needs a separate but connected model for execution.

When discussion becomes work, Orbit should create a `workstream` linked to the
origin thread.

A workstream should track:

- purpose
- requested outcome
- assigned participants or agents
- current status
- progress events
- artifacts produced
- completion or failure summary

This lets Orbit keep the main discussion readable while still supporting deeper
parallel work.

### 6. Realtime Model

Clients should subscribe to a canonical server-side event stream.

Important event classes:

- message created
- meeting started
- participant invited
- activation resolved
- workstream launched
- workstream progress updated
- artifact attached
- journal proposed
- memory candidate proposed
- review completed

The UI should use these events to power:

- live message delivery
- presence and activity indicators
- trace panels
- progress views
- notifications

## Primary Feature Set And How It Ties Together

### Feature 1: Workspace Command Center

The macOS app should open into a room-aware command center.

Visible elements:

- workspace context
- roster and availability
- active channels and threads
- pinned notes and decisions
- live workstreams
- trace and review panels

This is the surface that makes Orbit feel like Orbit.

### Feature 2: Team And Squad Collaboration

Teams and squads should be first-class addressing targets.

When AJ says "ask the Engineering Team," Orbit should:

1. resolve the team roster
2. decide whether the exchange is a simple thread response or a meeting
3. create participant records
4. run activations through PersonaKit
5. stream attributed replies back into the thread

### Feature 3: Threaded Meetings

Meetings should be attached to threads and preserve continuity.

Meeting output should include:

- meeting summary
- explicit decision or no-decision state
- open questions
- follow-up workstreams
- references and attachments

### Feature 4: Notes, Decisions, And References

Every serious thread should be able to accumulate structured objects.

#### Notes

Working understanding, evolving summaries, and meeting outputs.

#### Decisions

Committed choices with rationale, tradeoffs, dissent, and linked evidence.

#### References

Docs, links, files, commits, issues, and research artifacts that support the
conversation.

These structured objects keep important context from getting buried in message
history.

### Feature 5: Journaling And Memory Review

Orbit should turn important discussion into candidate learning, not directly into
behavioral drift.

The review surface should show:

- source thread
- proposed summary
- proposed memory scope
- why the memory matters
- what future work it should influence
- approve, reject, or revise actions

### Feature 6: Workstreams

Workstreams are the bridge between discussion and execution.

Examples:

- research sweep
- spec draft
- design exploration
- implementation lane
- QA review
- release checklist

Workstreams should feel like threaded child lanes, not like detached job IDs.

## End-To-End Flow

The main Orbit loop should look like this:

```text
AJ posts in a thread
  -> Thread service persists the message
  -> Meeting Coordinator decides the response mode
  -> PersonaKit resolves active persona contracts
  -> Orbit runner executes one or more turns
  -> Messages and events stream back to clients
  -> Notes / decisions / artifacts are attached to the thread
  -> Optional workstream is launched for deeper execution
  -> Journal and memory candidates are proposed
  -> AJ reviews what becomes durable memory
```

That single loop ties together the product experience.

## Orbit Server: Self-Hosted Deployment Shape

Orbit should be able to run on a reasonably powered personal machine.

### Recommended host profile

- Mac mini M4 or M5 class machine
- always-on local network presence
- local SSD for fast database and artifact access
- optional NAS or external disk for archive and backups

### Orbit Server responsibilities

- canonical runtime API
- realtime fan-out
- PersonaKit resolution calls
- agent or model execution brokering
- journaling and memory review pipeline
- search and indexing
- attachment handling
- backup and restore workflows

### Storage model

- relational database for runtime state
- local file or object storage for attachments and artifacts
- append-friendly event log for replay and debugging
- backup snapshots to local or user-owned storage

### Default practical stack

Orbit should favor boring, portable defaults for the first self-hosted release.

- native SwiftUI clients for Apple platforms
- one Orbit Server process exposing REST plus WebSocket or SSE
- SQLite for single-host installs, with a clean path to Postgres later
- local disk-backed artifact storage, with optional NAS or object-storage bridge
- a background job runner for meetings, journals, memory review, and workstreams

The goal is not maximal scale. The goal is reliable founder-scale operation on a
personal machine.

### Provider model

Orbit should support multiple execution providers:

- local models when available
- hosted model APIs when useful
- specialized external tools when explicitly authorized

The important rule is that Orbit Server owns the collaboration truth even when a
model provider performs the inference.

## Implementation Influences

Orbit should borrow intelligently without making external systems part of its
identity.

### How StandardAgents Applies

StandardAgents is useful as a reference model for Orbit, not as Orbit's required
foundation.

### Concepts Orbit should adopt

- durable thread-centric runtime
- child workstreams or subthreads for delegated work
- per-thread file scope
- streaming event model for live UI
- UI-friendly grouping of tool and work activity
- explicit lifecycle states for child work

### Concepts Orbit should replace

- Cloudflare Durable Object dependency
- proprietary builder dependence
- thread-id-as-capability auth assumptions
- runtime ownership of persona identity and policy

### Practical conclusion

Orbit should be StandardAgents-shaped in its runtime ideas while staying portable
enough to run as a self-hosted local server.

In short:

> Borrow the thread model, subthread model, and streaming model.
> Replace the hosting assumptions and policy model.

### How Dmux Applies

Dmux is useful to Orbit in two different ways, but only one of them should be a
product commitment.

### 1. Immediate value: development acceleration

Dmux is a strong tool for building Orbit faster.

Use it for:

- multi-lane implementation work
- isolated worktrees and branches
- agent-assisted parallel research and coding
- operator visibility into execution lanes

This should increase development velocity without shaping the Orbit user-facing
experience.

### 2. Optional later value: hidden execution substrate

If Orbit later supports repository-backed implementation workstreams, Dmux could
serve as a backstage executor that spins up isolated local lanes and streams
progress back into Orbit.

If that ever happens, the rule should be:

- Dmux stays invisible to the primary Orbit user experience
- Orbit owns the collaboration and review surface
- PersonaKit still governs agent identity and rules

### Practical conclusion

Dmux should not be treated as a foundational Orbit product dependency.
It should be treated as:

- a near-term development accelerator
- an optional hidden execution helper for future repo workstreams

## Dependency Positioning

### PersonaKit

Foundational and required.

### Orbit runtime and clients

Foundational to the product.

### StandardAgents

Reference architecture and inspiration source. Potential adapter target later,
but not a required dependency for the first durable Orbit architecture.

### Dmux

Development dependency and optional backstage execution dependency. Not a core
part of the Orbit product promise.

## MVP Direction

The first believable Orbit MVP should prove the collaboration model, not the
entire platform.

### Product truths to prove

The MVP should prove four things decisively.

1. A founder can ask a team for input and inspect why each participant responded.
2. A thread can escalate into a meeting and settle back into a thread without
   losing continuity.
3. A thread can launch a workstream and receive durable progress, artifacts, and
   closeout back into the same context.
4. Important activity can become reviewable journal and memory candidates rather
   than disappearing into chat history.

### Minimum build scope

- one self-hosted Orbit Server
- one great macOS command-center client
- one workspace with visible roster
- durable threads with attributed responses
- lightweight thread-attached meetings
- notes and decisions attached to threads
- inspectable PersonaKit activation context
- journal and memory candidate proposal flow
- at least one workstream type with progress and artifacts

### Explicitly deferred

- full public SaaS hosting
- heavy enterprise admin layers
- deep workflow automation marketplaces
- broad third-party connector catalog
- Dmux-backed execution as a required runtime feature

## How To Verify This Vision

This document is useful only if it drives concrete evaluation.

Verify it by asking:

1. Can a new reader explain the difference between PersonaKit and Orbit after
   reading this?
2. Can they describe Orbit as a collaboration product rather than a chat app?
3. Can they see where threads, meetings, memory, and workstreams fit together?
4. Can they tell why StandardAgents and Dmux are influences rather than default
   foundations?
5. Can they imagine running an Orbit Server on personal hardware without a large
   cloud platform?

## Related Docs

- [Orbit Docs Index](../README.md)
- [Orbit Platform Architecture Overview](../Architecture/PersonaKit-System-Overview.md)
- [Meeting Execution Flow](../Architecture/Meeting-Execution-Flow.md)
- [RFC-0002: Conversation and Memory Data Model](../RFCs/RFC-0002-Conversation-and-Memory-Data-Model.md)
- [RFC-0003: Workspace and Persona Instance Model](../RFCs/RFC-0003-Workspace-and-Persona-Instance-Model.md)
- [RFC-0004: Teams, Squads, and Meeting Coordinator Model](../RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md)
- [RFC-0006: Multi-Client Platform Architecture](../RFCs/RFC-0006-Multi-Client-Platform-Architecture.md)
- [Orbit macOS Command Center](../Planning/Orbit-macOS-Command-Center.md)
