# RFC-0006: Orbit Multi-Client Platform Architecture

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
- RFC-0002: Collaboration Runtime and Memory Data Model
- RFC-0003: Workspace, Group, and Workspace Persona Instance Model
- RFC-0004: Teams, Squads, and Meeting Coordinator Model
- RFC-0005: Memory Journaling and Gardening Model
- Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC defines Orbit's multi-client platform architecture.

Orbit is the collaboration platform. PersonaKit is the authored-contract engine
inside it. Orbit needs one canonical backend system that can serve multiple
specialized native clients without allowing those clients to invent different
runtime rules or competing sources of truth.

This RFC proposes a platform architecture where:

- one canonical `Orbit Server` owns runtime truth
- macOS, iPhone, and iPad are purpose-specific client surfaces over that shared
  truth
- realtime updates project persisted state across devices
- contract resolution, coordination, execution, journaling, and memory
  governance remain server-side
- transactional state and artifact storage are separated
- the default deployment model is self-hosted and private

This RFC treats a `Mac mini + Synology NAS` topology as the recommended
reference deployment, not a hard requirement. It also assumes a monolith-first
backend deployment with logical service boundaries inside one Orbit Server.

---

## 2. Motivation

The previous RFCs define Orbit's core behavior and structure:

- RFC-0001 defines workspace persona contract resolution and activation
- RFC-0002 defines the collaboration runtime and memory data model
- RFC-0003 defines workspace, group, and workspace persona instance structure
- RFC-0004 defines group orchestration through the Meeting Coordinator
- RFC-0005 defines memory journaling, review, and approved-memory governance

But none of that matters if the platform does not support how Orbit is actually
meant to be used:

- command-center work on macOS
- quick interaction, approvals, and alerts on iPhone
- meeting and roster-heavy collaboration on iPad
- durable multi-device coordination over one shared backend
- private infrastructure under operator control
- one system image that all devices and future services agree on

Without a platform RFC, the risk is that:

- each client grows its own assumptions
- sync behavior becomes fuzzy
- runtime logic drifts across clients
- memory and coordination state diverge
- Orbit fragments into disconnected apps instead of one system

This RFC exists to define the platform shape before implementation drifts.

---

## 3. Problem Statement

Orbit needs a platform architecture that can answer the following clearly:

- Which system components are authoritative?
- Which responsibilities belong on clients versus Orbit Server?
- How do macOS, iPhone, and iPad differ in purpose without diverging in
  behavior?
- How should realtime updates work across all clients?
- How does the system behave when a client is offline, stale, or partially
  connected?
- How are heavy runtime tasks separated from artifact storage?
- How should self-hosted hardware topology support privacy, durability, and low
  cost?
- How does the platform preserve one coherent source of truth across all
  devices?

Without explicit answers, Orbit risks:

- duplicated logic across apps
- inconsistent coordination behavior
- divergent post, thread, and memory state
- brittle sync
- weak operational clarity
- accidental architecture by implementation

---

## 4. Goals

This RFC aims to establish a platform architecture that:

- supports macOS, iPhone, and iPad as first-class clients
- centralizes canonical runtime state in Orbit Server
- provides realtime synchronization across devices
- keeps contract resolution, coordination, and memory governance server-side
- supports self-hosted/private-cloud deployment with strong durability
- uses a monolith-first deployment shape with clear logical service boundaries
- separates transactional state from long-term artifact storage
- uses an object-style artifact storage abstraction from day one
- supports offline intent queueing and reconnect behavior cleanly
- preserves a single source of truth for:
  - workspaces and groups
  - channels, posts, threads, and messages
  - meeting and workstream state
  - journaling and memory state
  - activation and run traces
- supports future external connectors without making them authoritative

---

## 5. Non-Goals

This RFC does not define:

- the final SwiftUI navigation structure for any app
- the exact authentication provider or token format
- the exact network protocol details for every endpoint
- the exact transport used for every realtime stream
- the final push-notification strategy
- the final database schema details
- the final containerization or deployment manifests
- public SaaS multi-tenant hosting
- immediate service decomposition from day one
- App Store release strategy

Those should follow in later implementation specs or narrower RFCs.

---

## 6. Proposal

Orbit should be modeled as a central platform with specialized clients.

The core proposal is:

- one canonical `Orbit Server` owns runtime truth
- client apps are purpose-specific surfaces over that shared truth
- Orbit Server contains clear logical domains for:
  - gateway and realtime
  - collaboration orchestration
  - PersonaKit contract resolution
  - execution runners
  - journaling and memory governance
  - persistence and storage adapters
- artifact storage is separated from transactional state
- the default deployment model is self-hosted and private

### Core design law

> Clients present the system.
> Orbit Server owns the system.

This means:

- no client should own canonical meeting or workstream state
- no client should own memory-promotion truth
- no client should resolve workspace persona contracts independently
- no client should become a second backend by accident

---

## 7. Ownership Boundary

RFC-0006 owns:

- client roles and client/backend responsibility split
- canonical-source-of-truth rules
- realtime and sync semantics
- deployment topology and hosting guidance
- external capability boundary rules

RFC-0006 does not own:

- runtime entity schema (`RFC-0002`)
- activation semantics (`RFC-0001`)
- workspace/group structure semantics (`RFC-0003`)
- memory lifecycle semantics (`RFC-0005`)

---

## 8. Architectural Overview

The architecture should be understood as layered around one Orbit Server.

```text
Operator
  -> Orbit Client Apps
  -> Orbit Gateway / Realtime
  -> Orbit Collaboration Services
  -> PersonaKit Resolver
  -> Execution Runners
  -> Persistence + Artifact Storage
  -> Hardware / Infrastructure
```

### 8.1 Monolith-first shape

Orbit should begin with one deployable Orbit Server rather than a set of
separately deployed microservices.

Inside that server, the platform should still preserve logical service
boundaries so later decomposition remains possible if growth demands it.

This gives Orbit:

- operational simplicity for self-hosted deployment
- one canonical backend boundary
- lower infrastructure burden for early development and adoption
- cleaner future service extraction if needed later

---

## 9. Client Model

Orbit should support three primary client classes.

### 9.1 macOS app

The macOS app is the command center.

This is the richest operational surface and should be the best place to:

- manage workspaces and channels
- inspect posts, threads, meeting posts, and workstream posts
- inspect coordinator behavior and runtime traces
- review journals and memory
- inspect failures and lineage
- manage team and squad composition
- review notes, decisions, references, and artifacts

The macOS app should be the best place for:

- administration
- diagnosis
- editing
- high-fidelity inspection

### 9.2 iPhone app

The iPhone app is the fast interaction and approval surface.

This app should prioritize:

- quick interaction
- alerts and notifications
- reading responses on the go
- approving or rejecting memory
- seeing meeting or workstream completion
- reading summaries
- lightweight workspace switching

The iPhone app should not try to become a full operations console.
It should optimize for:

- speed
- clarity
- interruption-friendly workflows

### 9.3 iPad app

The iPad app is the meeting and collaboration surface.

This app should be optimized for:

- side-by-side collaborator responses
- roster inspection
- meeting-post and workstream-post review
- summary panels
- comparison views
- timeline or event inspection
- multi-column workspace views

The iPad should feel like:

- a meeting table
- a planning surface
- a live collaboration board

### 9.4 Shared client principle

All clients should consume the same canonical platform state.

Differences between clients should be:

- surface area
- density
- workflow emphasis

Not:

- different rules
- different runtime logic
- different memory truth

---

## 10. Gateway and Realtime Layer

Orbit Server needs a gateway layer that acts as the front door for all clients.

Responsibilities should include:

- authentication and request validation
- post, thread, and message ingestion
- workspace and group APIs
- artifact access and upload coordination
- journal and memory-review APIs
- realtime subscription management
- snapshot and replay entry points for reconnect behavior

### 10.1 Realtime requirements

Because posts, meeting state, workstream state, and memory review span multiple
devices, the platform needs a realtime model.

Minimum event categories should include:

- `post.created`
- `post.status.changed`
- `message.created`
- `thread.activity.updated`
- `meeting.started`
- `meeting.completed`
- `participant.joined`
- `participant.failed`
- `journal.created`
- `memory.candidate.created`
- `memory.reviewed`
- `memory.approved`
- `workstream.started`
- `artifact.attached`

### 10.2 Transport flexibility

Realtime semantics should be authoritative, but transport should remain
flexible.

Acceptable implementations may include:

- `WebSocket`
- `SSE`
- future push layers or transport adapters

### 10.3 Design law

> Realtime is a projection of durable state, not a second source of truth.

That means:

- events should reflect persisted transitions
- clients should be able to reconstruct state from stored records
- reconnect should recover by snapshot and replay, not guesswork

---

## 11. Collaboration and Runtime Services

Orbit Server should separate client access from behavior through logical service
domains.

### 11.1 Collaboration services

These domains own:

- meeting creation and promotion
- participant selection
- team and squad expansion
- meeting lifecycle
- completion decisions
- summary and follow-up triggers
- workstream handoff triggers

This is the territory of the Meeting Coordinator model defined in RFC-0004.

### 11.2 PersonaKit resolver

This domain owns:

- workspace persona contract resolution
- directive resolution
- kit resolution
- authorized skill resolution
- stop point and review-gate resolution
- memory eligibility inputs for activation

This aligns with RFC-0001.

### 11.3 Execution runners

These domains own:

- provider execution
- trace capture
- response persistence
- run status reporting

This execution layer remains separate from the authored contract layer.

### 11.4 Memory services

These domains own:

- journal generation
- memory candidate generation
- memory review orchestration
- stewardship workflows
- lineage and indexing support

This aligns with RFC-0005.

---

## 12. Persistence and Artifact Storage

The platform should distinguish between transactional truth and artifact storage.

### 12.1 Transactional state

Transactional state belongs in the relational database.

Examples:

- workspaces
- channels
- teams
- squads
- workspace personas
- workspace persona memberships
- posts
- threads
- messages
- post events
- post links
- notes
- decisions
- references
- meeting state
- meeting members
- workstream state
- persona activations
- agent runs
- journal entries
- memory candidates
- memory reviews
- memory entries

This aligns with RFC-0002 and companion RFCs.

### 12.2 Artifact storage

Large and durable file-like artifacts belong in artifact storage.

Examples:

- exported docs
- research files
- long-form reports
- generated outputs
- snapshots
- pack archives
- attachments

### 12.3 Object-style storage abstraction

Orbit should code against an object-style storage abstraction from day one, even
if the first implementation is backed by a local filesystem or NAS.

This keeps the system portable across:

- local disk
- NAS-backed storage
- later object-store backends

### 12.4 Design law

> Database for runtime truth.
> Object-style artifact storage for large durable files.

---

## 13. Offline and Sync Model

Because Orbit includes mobile clients, offline handling matters.

### 13.1 Canonical principle

Orbit Server remains the canonical source of truth.

Clients may have:

- local caches
- pending drafts
- queued intents
- optimistic UI states

But they must not invent:

- persona activations
- coordinator outcomes
- approved memory
- canonical post, meeting, or workstream state

### 13.2 Offline behavior

Suggested rules:

#### If a client is offline while composing a post or reply

- preserve the draft locally
- allow queued send
- sync when connectivity resumes

#### If a send succeeds but the client is stale

- refresh from canonical state after reconnect
- reconcile through snapshot plus event replay where needed

#### If approvals are made offline

- queue the action locally
- reconcile on reconnect
- handle conflict visibly if memory state changed in the meantime

#### If replay has gaps or local cache is stale

- fetch a fresh snapshot
- replay from a trusted checkpoint
- do not guess missing state locally

### 13.3 Design law

> Clients may queue intent.
> Only Orbit Server may finalize truth.

---

## 14. Hardware and Deployment Model

This RFC assumes a private, self-hosted deployment model as the default.

### 14.1 Reference topology

The recommended reference topology is:

- `Mac mini` class compute host
- `Synology NAS` or equivalent storage host

This is a recommended topology, not a hard requirement.

### 14.2 Compute host

Recommended primary compute host:

- `Mac mini`

Responsibilities:

- Orbit Server
- gateway and realtime
- collaboration services
- PersonaKit resolver
- execution runners
- memory services
- relational database
- background jobs

### 14.3 Storage host

Recommended artifact and backup host:

- `Synology NAS`

Responsibilities:

- artifact storage backend
- backups
- snapshots
- archives
- pack and document vault

### 14.4 Why this split

The `Mac mini` acts as the brain.
The NAS acts as the vault.

This split keeps:

- compute, coordination, and database work on the compute host
- large durable storage and backup on the storage host

Smaller self-hosted deployments may colocate these concerns temporarily, but the
reference topology remains a strong default.

### 14.5 Network posture

The system should be designed for:

- local/private network first
- remote access second
- public internet exposure only when intentionally designed

This keeps:

- cost low
- privacy high
- operational complexity manageable

---

## 15. External Capability Surfaces

Orbit may integrate external capability providers, but they should remain
non-authoritative.

Examples:

- model APIs
- GitHub APIs
- MCP servers
- future research or analysis tools

### 15.1 Design law

> External systems provide capability, not authority.

That means:

- PersonaKit provides authored contract truth
- Orbit Server resolves runtime state and enforces platform behavior
- external systems do not become the source of truth for identity, memory, or
  coordination state

---

## 16. UX / Product Implications

This RFC implies several product truths.

### 16.1 macOS is not the platform

The macOS app is the richest client, not the canonical system.

### 16.2 iPhone is not a lesser copy of macOS

It should optimize around:

- fast interaction
- approvals
- alerts
- summaries

### 16.3 iPad should differentiate through meeting ergonomics

It should be the best place for:

- roster review
- live meeting observation
- collaborator comparison
- review and synthesis

### 16.4 Platform language matters

The product should feel like:

- one system across devices

not:

- three different apps with similar branding

---

## 17. Failure Modes and Edge Cases

### 17.1 Realtime connection drops

- client should reconnect
- recover via snapshot and event replay
- avoid assuming local state is complete

### 17.2 One client is stale while another is current

- stale client must reconcile from server truth
- no local override of canonical meeting, workstream, or memory state

### 17.3 Gateway unavailable

- clients may still preserve drafts locally
- no durable write occurs until service recovers

### 17.4 Collaboration service unavailable

- post persistence may still succeed
- coordination failure must remain visible
- retries should be possible

### 17.5 Artifact storage unavailable

- transactional state should still function where possible
- artifact-heavy operations may degrade separately

### 17.6 Database unavailable

- no canonical state change should be finalized
- clients should not fake durable success

### 17.7 Device-specific UX divergence

- different clients may surface different workflows
- they must not implement different underlying rules

### 17.8 Offline approval conflict

- queued approval must reconcile against current server truth
- visible conflict resolution is required when state changed in the meantime

---

## 18. Alternatives Considered

### Alternative A: Local-first apps with optional backend sync

Rejected because:

- Orbit's direction centers on durable coordinated runtime state
- multi-device collaboration needs a canonical backend

### Alternative B: macOS as the only serious client

Rejected because:

- iPhone and iPad meaningfully expand how an operator runs the system
- approvals, summaries, and collaboration deserve tailored surfaces

### Alternative C: Clients own more runtime logic

Rejected because:

- behavior drift follows quickly
- the system becomes harder to reason about
- trust and explainability weaken

### Alternative D: Service-first decomposition from day one

Rejected because:

- it adds operational burden too early
- a monolith-first deployment is better suited to self-hosted adoption
- logical service boundaries can still be preserved inside Orbit Server

### Alternative E: NAS as primary compute host

Rejected because:

- a storage appliance is the wrong home for coordination and database-heavy
  compute
- it is better used as the vault, not the brain

### Alternative F: Public SaaS-first multi-tenant design

Rejected for now because:

- current product direction is private, operator-led, and self-hosted
- multi-tenant SaaS concerns would distort early architecture

---

## 19. Risks and Tradeoffs

### Risk: More backend complexity earlier

This architecture centralizes a lot.

Tradeoff:

- the product vision requires central truth and coordination
- avoiding that complexity would only defer it into worse places

### Risk: Multi-client product surface may grow too broad

Three apps create design and implementation overhead.

Tradeoff:

- each client has a distinct strategic role
- platform centralization reduces behavioral divergence

### Risk: Private-cloud deployment still has operational burden

Tradeoff:

- cost and privacy advantages remain strong
- separation of compute and storage reduces strain

### Risk: Realtime architecture adds complexity

Tradeoff:

- meeting and multi-device collaboration feel broken without it
- durable-state-first design contains the complexity

### Risk: Monolith-first architecture may blur service boundaries

Tradeoff:

- one deployable Orbit Server simplifies operations early
- logical service separation should still be preserved so later decomposition
  remains possible

---

## 20. Open Questions

- Should the first mobile client be iPhone or iPad?
- Should notifications be gateway-managed or delegated to a dedicated service
  later?
- How much local caching should each client perform?
- Should macOS retain admin-only surfaces not exposed on mobile?
- Should there be a web client eventually, or remain native-first?
- When should Orbit Server be decomposed beyond a monolith-first deployment?

---

## 21. Recommendation

Adopt the multi-client platform model as Orbit's platform architecture.

Specifically:

- treat Orbit Server as the canonical source of truth
- keep client apps surface-specific, not behavior-specific
- centralize coordination, contract resolution, execution, memory, and
  persistence server-side
- use the `Mac mini + Synology NAS` split as the recommended reference topology
- support realtime synchronization across all clients while keeping transport
  flexible
- use an object-style artifact storage abstraction from day one
- keep external providers as capability surfaces only

This is the strongest platform architecture for Orbit's operator-led,
multi-client, self-hosted direction.

---

## 22. Rollout / Adoption Plan

### Phase 1

Introduce:

- Orbit Server as the canonical backend
- macOS client as the first rich client
- durable post and thread runtime
- realtime event stream
- basic artifact-storage abstraction

Goal:

- one authoritative system with one rich control surface

### Phase 2

Introduce:

- iPhone client
- notifications
- local draft queue and offline intent handling
- approval reconciliation on reconnect

Goal:

- on-the-go interaction and governance

### Phase 3

Introduce:

- iPad client
- meeting-first layouts
- roster and comparison surfaces
- richer collaboration panels

Goal:

- multi-pane collaboration experience over one shared backend

### Phase 4

Introduce:

- deeper operational tooling
- richer storage backends
- historical inspection and analytics
- optional service decomposition later if justified

Goal:

- mature platform architecture rather than a collection of apps

---

## 23. Self-Review

- Does this architecture preserve one source of truth across devices?
  Yes.

- Does it keep client responsibilities distinct without making them
  inconsistent?
  Yes.

- Does it keep Orbit as the platform and PersonaKit as the contract engine?
  Yes.

- Does it support a monolith-first deployment while preserving logical service
  boundaries?
  Yes.

- Does it treat the `Mac mini + Synology NAS` split as a recommended topology
  rather than a hard requirement?
  Yes.

- Does it leave realtime transport flexible while keeping semantics durable and
  authoritative?
  Yes.

---

## 24. Decision Log

- 2026-03-08 - Initial draft created
- 2026-03-17 - Reframed RFC around Orbit as the platform and PersonaKit as the
  authored-contract engine
- 2026-03-17 - Adopted Orbit Server as the monolith-first canonical backend with
  logical service boundaries
- 2026-03-17 - Treated `Mac mini + Synology NAS` as the recommended reference
  topology rather than a strict requirement
- 2026-03-17 - Kept realtime semantics authoritative while leaving transport
  flexible
- 2026-03-17 - Adopted an object-style artifact storage abstraction from day one
