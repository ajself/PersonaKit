# RFC-0006: Multi-Client Platform Architecture

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
- RFC-0001 Workspace Persona Contract Resolution and Activation Model
- RFC-0002 Collaboration Runtime and Memory Data Model
- RFC-0003 Workspace and Persona Instance Model
- RFC-0004 Teams, Squads, and Meeting Coordinator Model
- RFC-0005 Memory Journaling and Gardening Model
- Docs/Orbit/Architecture/PersonaKit-System-Overview.md
- Docs/Orbit/Architecture/Meeting-Execution-Flow.md
- Docs/Orbit/RFCs/README.md

---

## 1. Summary

This RFC proposes the **multi-client platform architecture** for PersonaKit.

PersonaKit is no longer just a local grounding tool. It is becoming a **workspace-centric command center** for persistent AI teams, with conversations, meetings, memory, journaling, and cross-workspace learning. That direction implies a platform architecture where:

- multiple client apps connect to one canonical backend
- conversations and meetings are durable and replayable
- realtime updates keep all clients in sync
- identity, activation, coordination, memory, and storage are centralized
- hardware topology is intentional, not accidental

This RFC defines the platform shape across:

- macOS
- iPhone
- iPad
- gateway and realtime layers
- runtime and coordination services
- storage and artifact infrastructure
- local/private-cloud deployment model

This is a proposal, not a locked implementation.

---

## 2. Motivation

The previous RFCs define PersonaKit’s core behavior:

- personas activate through workspace instances and directives
- conversations, meetings, journals, and memory are durable runtime artifacts
- teams and squads provide collaboration structure
- memory grows through journaling, review, and gardening rather than uncontrolled accumulation fileciteturn18file1 fileciteturn18file2 fileciteturn18file3 fileciteturn18file6 fileciteturn18file7

But none of that matters if the platform does not support the way you actually want to use it:

- command-center style work on macOS
- quick interaction and approvals on iPhone
- meeting-first collaboration on iPad
- durable cloud-style coordination
- private infrastructure under your control
- one system image that all devices and future services agree on

Without a platform RFC, the risk is that each client grows its own assumptions, sync behavior becomes fuzzy, and the “one human at the center of AI teams” vision fragments into disconnected surfaces.

This RFC exists to define the platform shape before implementation drifts.

---

## 3. Problem Statement

PersonaKit needs a platform architecture that can answer:

- Which system components are authoritative?
- Which responsibilities belong on clients vs backend services?
- How do macOS, iPhone, and iPad differ in purpose without diverging in behavior?
- How should realtime updates work?
- How does the system behave when clients are offline or stale?
- How are heavy runtime tasks separated from artifact storage?
- How does the hardware topology support privacy, durability, and low cost?
- How does the system preserve one coherent source of truth across all devices?

Without explicit answers, PersonaKit risks:

- duplicated logic across apps
- inconsistent meeting behavior
- divergent memory state
- brittle sync
- weak operational clarity
- accidental architecture by implementation

---

## 4. Goals

This RFC aims to establish a platform architecture that:

- supports macOS, iPhone, and iPad as first-class clients
- centralizes canonical runtime state in backend services
- provides realtime synchronization across devices
- keeps persona activation, coordination, and memory policies server-side
- supports local/private-cloud deployment with strong durability
- separates compute from long-term artifact storage
- supports offline and reconnect behavior cleanly
- preserves a single source of truth for:
  - conversations
  - meetings
  - memory
  - persona runtime state
- supports future external connectors without making them authoritative

---

## 5. Non-Goals

This RFC does not define:

- the final SwiftUI navigation structure for any app
- the exact authentication provider or token format
- the exact network protocol details for every endpoint
- the final push notification strategy
- the final database schema details
- the final containerization or deployment manifests
- public SaaS multi-tenant hosting
- App Store release strategy

Those should follow in later implementation specs or narrower RFCs.

---

## 6. Proposal

PersonaKit should be modeled as a **central platform with specialized clients**.

The core proposal is:

- one canonical backend platform owns runtime truth
- client apps are purpose-specific interfaces to that shared truth
- backend services own coordination, activation, memory, journaling, and persistence
- artifact storage is separated from transactional state
- the deployment model is private-cloud / self-hosted by default

### Core design law

> Clients present the system.  
> The platform owns the system.

This means:
- no client should own canonical meeting state
- no client should own memory promotion truth
- no client should resolve persona activation independently
- no client should become a second backend by accident

---

## 7. Architectural Overview

The architecture should be understood as six layers:

```text
Human
  ↓
Client Apps
  ↓
Gateway + Realtime
  ↓
Coordination + Runtime Services
  ↓
Persistence + Artifact Storage
  ↓
Hardware / Infrastructure
```

This matches the system overview already established, while making the client and hosting responsibilities explicit. fileciteturn18file4

---

## 8. Client Model

PersonaKit should support three primary client classes.

### 8.1 macOS App

The macOS app is the **command center**.

This is the richest operational surface and should be the place where the user can:

- manage workspaces
- manage persona templates and workspace personas
- inspect conversations and meetings
- inspect coordinator behavior
- review and manage memory
- inspect journals
- inspect traces and failures
- manage team and squad composition
- review summaries and artifacts

The macOS app should be the best place for:
- editing
- administration
- diagnosis
- high-fidelity inspection

### 8.2 iPhone App

The iPhone app is the **fast interaction and approval surface**.

This app should prioritize:
- quick chat
- notifications
- reading responses on the go
- approving or rejecting memory
- seeing meeting completion
- reading summaries
- lightweight workspace switching

The iPhone app should not try to be a full operations console.
It should be optimized for:
- speed
- clarity
- interruption-friendly workflows

### 8.3 iPad App

The iPad app is the **meeting and collaboration surface**.

This app should be optimized for:
- side-by-side persona responses
- roster inspection
- team and squad conversations
- summary panels
- memory review panels
- timeline or event inspection
- multi-column workspace views

The iPad should feel like:
- a meeting table
- a planning surface
- a live collaboration board

### 8.4 Shared client principle

All clients should consume the same canonical platform state.
Differences should be:
- surface area
- density
- workflow emphasis

Not:
- different rules
- different runtime logic
- different memory truth

---

## 9. Gateway and Realtime Layer

PersonaKit needs a Gateway layer that acts as the front door for all clients.

Responsibilities should include:

- authentication and request validation
- message ingestion
- conversation CRUD surfaces
- workspace and roster APIs
- memory review APIs
- journal and summary retrieval
- realtime subscription management

### 9.1 Realtime requirements

Because conversations, meetings, and memory reviews span multiple devices, the platform needs a realtime model.

Minimum event categories should include:

- message.created
- message.updated
- response.started
- response.completed
- meeting.created
- meeting.completed
- participant.joined
- participant.failed
- summary.created
- journal.created
- memory.candidate.created
- memory.reviewed
- memory.approved

### 9.2 Design law

> Realtime is a projection of durable state, not a second source of truth.

That means:
- events should reflect persisted transitions
- clients should be able to reconstruct state from stored records
- reconnect should recover by replay or snapshot, not guesswork

---

## 10. Coordination and Runtime Services

The platform backend should separate client access from behavior.

### 10.1 Coordination services

These services own:
- meeting creation
- participant selection
- squad/team expansion
- meeting lifecycle
- completion decisions
- summary triggers
- journaling triggers
- memory candidate trigger decisions

This is the territory of the Meeting Coordinator model already proposed. fileciteturn18file6

### 10.2 Persona runtime services

These services own:
- persona activation
- directive resolution
- memory retrieval
- context assembly
- provider execution
- trace capture
- response persistence

This aligns with the activation and conversation/memory RFCs already drafted. fileciteturn18file1 fileciteturn18file2

### 10.3 Memory services

These services own:
- journal generation
- memory candidate generation
- stewardship workflows
- memory review orchestration
- retrieval indexing and lineage

This aligns with RFC-0005’s journaling and gardening model. fileciteturn18file7

---

## 11. Persistence Model

The platform should distinguish between **transactional truth** and **artifact storage**.

### 11.1 Transactional state

Transactional state belongs in the relational database.

Examples:
- workspaces
- teams
- squads
- conversations
- messages
- meetings
- activations
- runs
- journals
- memory candidates
- memory entries
- summaries

This model is already established in RFC-0002. fileciteturn18file2

### 11.2 Artifact storage

Large and durable file-like artifacts belong in artifact storage.

Examples:
- exported docs
- research files
- long-form summaries
- generated reports
- snapshots
- pack archives
- attachments later

### 11.3 Design law

> Database for runtime truth.  
> Artifact storage for large durable files.

---

## 12. Offline and Sync Model

Because clients include mobile devices, offline handling matters.

### 12.1 Canonical principle

The server remains the canonical source of truth.

Clients may have:
- local caches
- pending drafts
- optimistic UI states

But they must not invent:
- persona activations
- meeting completions
- approved memory
- canonical coordinator outcomes

### 12.2 Offline behavior

Suggested rules:

#### If client is offline when composing a user message
- preserve draft locally
- allow queued send
- sync when connectivity resumes

#### If message send succeeds but updates are stale
- client should refresh from canonical state after reconnect

#### If approvals are made offline
- queue action locally
- reconcile on reconnect
- handle conflict visibly if memory state changed in the meantime

### 12.3 Design law

> Clients may queue intent.  
> Only the platform may finalize truth.

---

## 13. Hardware and Deployment Model

This RFC assumes a private, self-hosted deployment model as the default.

### 13.1 Compute node

Recommended primary compute host:
- Mac mini

Responsibilities:
- gateway/API
- realtime service
- coordination services
- persona runtime
- memory services
- Postgres
- background jobs

### 13.2 Storage node

Recommended artifact and backup host:
- Synology NAS

Responsibilities:
- artifact storage
- backups
- snapshots
- archives
- pack and document vault

### 13.3 Why this split

The system overview already established the Mac mini as the “brain” and the Synology as the “vault.” fileciteturn18file4 This RFC formalizes that split:

- compute, coordination, and database live on the Mac mini
- large durable storage and backup live on the NAS

### 13.4 Network posture

The system should be designed for:
- local/private network first
- remote access second
- public internet exposure only when intentionally designed

This keeps:
- cost low
- privacy high
- operational complexity manageable

---

## 14. External Capability Surfaces

The platform may integrate external capability providers, but they should remain non-authoritative.

Examples:
- OpenAI Codex API
- GitHub API
- GitHub MCP server
- future research or analysis tools

### 14.1 Design law

> External systems provide capability, not identity or memory authority.

That means:
- persona identity comes from PersonaKit
- activation comes from PersonaKit
- memory policy comes from PersonaKit
- external systems do not become the source of truth

---

## 15. UX / Product Implications

This RFC implies several product truths.

### 15.1 macOS is not “the app”; it is “the console”
That distinction matters.
The macOS app is the richest client, not the canonical platform.

### 15.2 iPhone is not a lesser copy of macOS
It should be optimized around:
- fast interaction
- approvals
- alerts
- summaries

### 15.3 iPad should differentiate through meeting ergonomics
It should be the best place for:
- team chat
- live meeting observation
- persona comparison
- review and synthesis

### 15.4 Platform language matters
The product should feel like:
- one system across devices
not
- three different apps with similar branding

---

## 16. Failure Modes and Edge Cases

### 16.1 Realtime connection drops
- client should reconnect
- recover via snapshot + event replay
- avoid assuming local state is complete

### 16.2 One client is stale while another is current
- stale client must reconcile from server truth
- no local override of canonical meeting or memory state

### 16.3 Gateway unavailable
- clients may still preserve drafts locally
- no durable write occurs until service recovers

### 16.4 Runtime service unavailable
- message persistence may still succeed
- coordinator failure must remain visible
- retries should be possible

### 16.5 Artifact storage unavailable
- transactional state should still function where possible
- artifact-heavy operations may degrade separately

### 16.6 Database unavailable
- no canonical state change should be finalized
- clients should not fake durable success

### 16.7 Device-specific UX divergence
- different clients may surface different workflows
- but they must not implement different underlying rules

---

## 17. Alternatives Considered

### Alternative A: Local-first apps with optional backend sync
Rejected because:
- PersonaKit’s direction now centers around durable coordinated runtime state
- memory, meetings, and multi-device behavior need a canonical backend

### Alternative B: macOS as the only serious client
Rejected because:
- iPhone and iPad meaningfully expand how you run an incubator-style system
- approvals, summaries, and meetings deserve tailored surfaces

### Alternative C: Clients own more runtime logic
Rejected because:
- leads to behavior drift
- makes the system harder to reason about
- weakens trust and explainability

### Alternative D: NAS as primary compute host
Rejected because:
- storage appliance is the wrong home for runtime coordination and database-heavy compute
- better used as the vault, not the brain

### Alternative E: Public SaaS-first multi-tenant design
Rejected for now because:
- current product direction is private, founder-centered, and self-hosted
- multi-tenant SaaS concerns would distort early architecture

---

## 18. Risks and Tradeoffs

### Risk: More backend complexity earlier
This architecture centralizes a lot.

Tradeoff:
- the product vision requires central truth and coordination
- avoiding that complexity would only defer it into worse places

### Risk: Multi-client product surface may grow too broad
Three apps can create design and implementation overhead.

Tradeoff:
- each client has a distinct strategic role
- platform centralization reduces behavioral divergence

### Risk: Private-cloud deployment may still have operational burden
Tradeoff:
- cost and privacy advantages remain strong
- separation of compute and storage reduces strain

### Risk: Realtime architecture adds complexity
Tradeoff:
- meeting and multi-device collaboration feel broken without it
- durable-state-first design contains the complexity

---

## 19. Open Questions

- Should the first mobile client be iPhone or iPad?
- Should notifications be gateway-managed or delegated to a dedicated service later?
- Should artifact storage start as filesystem-backed on the NAS, or use an object-style abstraction from day one?
- How much local caching should each client perform?
- Should macOS retain any additional admin-only surfaces not exposed on mobile?
- Should there be a web client eventually, or remain native-app-first?

---

## 20. Recommendation

Adopt the multi-client platform model as PersonaKit’s platform architecture.

Specifically:

- treat the backend platform as the canonical source of truth
- keep client apps surface-specific, not behavior-specific
- centralize coordination, runtime, memory, and persistence server-side
- use the Mac mini as the primary compute host
- use the Synology NAS as artifact vault and backup target
- support realtime synchronization across all clients
- keep external providers as capability surfaces only

This is the strongest platform architecture for the workspace-centric, memory-bearing, incubator-scale direction PersonaKit is taking.

---

## 21. Rollout / Adoption Plan

### Phase 1
Introduce:
- canonical backend APIs
- macOS client as first rich client
- durable conversations and meetings
- realtime event stream
- basic artifact storage

Goal:
- one authoritative system with one rich control surface

### Phase 2
Introduce:
- iPhone client
- notifications
- lightweight approvals and summaries
- reconnect and local draft queue model

Goal:
- on-the-go interaction and governance

### Phase 3
Introduce:
- iPad client
- meeting-first layouts
- squad and roster views
- memory review panels
- richer live collaboration surfaces

Goal:
- multi-pane team collaboration experience

### Phase 4
Introduce:
- deeper operational tooling
- stronger artifact workflows
- richer analytics and historical inspection
- more mature private-cloud operations

Goal:
- mature platform rather than single-app product

---

## 22. Self-Review

- Does this architecture preserve one source of truth across devices?  
  Yes.

- Does it keep client responsibilities distinct without making them inconsistent?  
  Yes.

- Does it align with the prior RFCs and the system overview?  
  Yes.

- Does it support private, low-cost, high-control deployment?  
  Yes.

- Does it leave room for growth without locking every implementation detail?  
  Yes.

---

## 23. Decision Log

- 2026-03-08 — Initial draft created
