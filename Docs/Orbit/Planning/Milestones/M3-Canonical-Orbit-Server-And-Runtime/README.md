# M3 Canonical Orbit Server And Runtime Backbone

Status: Accepted
Primary Owner: `studio-integration-coordinator`
Supporting Personas: `architectural-editor`, `senior-swiftui-engineer`, `venture-product-steward`, `studio-reliability-engineer`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Move Orbit from a local proving surface to one canonical collaboration runtime.

## Quality Standard

`M3` is not successful because a server exists.

`M3` is successful only when Orbit Server becomes the one authoritative runtime
without weakening the product semantics proven in `M1` and `M2`.

The bare minimum is not a milestone win.
If the system gains backend complexity but still leaves room for dual truth,
trace drift, replay ambiguity, or client-owned runtime rules, `M3` has not been
reached.

Accepted here means this dossier is the approved planning baseline for `M3`.
The milestone still closes only when its exit criteria and review gate are
satisfied.

For `M3`, AI lanes should implement the approved server direction.
They should not treat runtime complexity as permission to revisit the core stack.

## File Map

- `README.md`
  milestone overview, packet order, and top-level guardrails
- `Quality-Bar.md`
  definition of impressive `M3` quality and disqualifying shortcuts
- `Canonical-Runtime-Contract.md`
  ownership boundary, minimum server-owned records, and client/server rules for
  canonical runtime truth
- `Canonical-Runtime-Boundary-Audit-Note.md`
  Packet 1 architecture review artifact comparing the accepted canonical contract
  to the current local Orbit runtime
- `Stack-Conformance-Review-Note.md`
  Packet 1 stack-fidelity artifact confirming the repo is still aligned to the
  approved `Swift + Vapor + Postgres` posture
- `Schema-And-Event-Model-Note.md`
  Packet 1 mapping note for the minimum runtime schema and initial durable event
  categories
- `Phase-1-Persistence-Bootstrap-Note.md`
  early Packet 2 artifact for the raw-SQL schema migrator and first canonical
  repository layer
- `Realtime-Projection-Contract-Note.md`
  early Packet 3 artifact freezing the event envelope, replay cursor, and
  ordering semantics before transport work begins
- `Realtime-Feed-And-Replay-Service-Note.md`
  early Packet 3 artifact for the transport-agnostic feed service that decides
  bootstrap, replay, no-change, and resync behavior
- `Database-Backed-Replay-Loader-Note.md`
  Packet 3 artifact for the database-backed event projection and transport-
  neutral subscription handshake layer
- `Polling-Session-Recovery-Note.md`
  Packet 3 artifact for stale-client recovery and polling/session semantics
- `Transport-Adapter-Contract-Note.md`
  Packet 3 artifact for the thin transport-facing request/response layer over the
  polling/session service
- `Artifact-Storage-Boundary-Note.md`
  Packet 4 artifact for the object-style storage abstraction and replaceable
  filesystem backend
- `macOS-Cutover-Projection-Note.md`
  early Packet 5 artifact for the client-side projection seam from canonical room
  truth into the Orbit macOS room model
- `Migration-Cut-Plan.md`
  ordered migration sequence from local proving loop to server-backed runtime
- `Golden-Canonical-Flow.md`
  deterministic end-to-end walkthrough of a correct server-backed Orbit flow
- `Failure-And-Recovery-Matrix.md`
  expected failure behavior for persistence, realtime, replay, and storage edges
- `Validation-And-Review-Matrix.md`
  architecture, reliability, migration, and evidence review matrix
- `Decision-Register.md`
  fixed stack posture plus remaining architecture and migration decisions that
  should not be answered implicitly in implementation
- `Evidence-And-Exit-Criteria.md`
  milestone-close rules and proof requirements
- `Architecture-Review-Artifact.md`
  current architecture readout for the canonical-runtime backbone
- `Reliability-Review-Artifact.md`
  current replay, recovery, and write-discipline review readout
- `Product-Continuity-Review-Artifact.md`
  current product continuity readout for the server-backed room model
- `Migration-Validation-Artifact.md`
  deterministic validation readout for the current `M3` slice
- `Review-Packet.md`
  compact AJ review packet for the current canonical-runtime backbone progress

## Preconditions

- `M1` is accepted as the identity and activation baseline for server migration
- `M2` is accepted as the local command-center baseline to preserve through
  migration
- the approved `M0` stack posture is accepted as binding for `M3`
- AJ and the `M3` review ring agree that server migration is now worth the added
  complexity

## Scope Freeze

In scope:

- Orbit Server as canonical source of truth
- RFC-0002 phase-1 runtime records
- realtime event stream
- artifact-storage abstraction
- macOS client migration from local truth to server-backed truth

Out of scope:

- iPhone and iPad clients
- team and squad orchestration logic beyond what runtime migration needs
- memory review and memory reuse
- service decomposition for its own sake

## Approved Stack Posture

- server language: `Swift`
- server framework: `Vapor`
- canonical transactional runtime store: `Postgres`
- deployment posture: self-hosted, private infrastructure, no managed cloud
  platform
- architecture posture: monolith-first, same-process PersonaKit resolver, no
  extra infrastructure tiers unless AJ explicitly approves them
- realtime posture: leaning `WebSocket`, `SSE` acceptable if it better preserves
  simplicity without weakening snapshot-plus-replay semantics
- artifact storage posture: object-style abstraction from day one with a leaning
  NAS-backed filesystem backend

These choices are implementation constraints, not prompts for further stack
selection.

If an AI lane believes one of these choices should change, it must stop and wait
for AJ to decide.

## Execution Boundary

- `M3` implementation work should run in a dedicated non-main worktree on its
  associated branch
- inside that worktree, AI lanes may make repo-wide changes that materially serve
  the canonical-runtime migration
- this includes replacing or removing legacy PersonaKit macOS app surfaces if
  they obstruct the active Orbit milestone
- this does not authorize redefining the approved Orbit product or stack posture

## Required Inputs

- `Docs/Orbit/Planning/Orbit-Agentic-Milestone-Roadmap.md`
- `Docs/Orbit/Planning/Milestones/M0-Agentic-Execution-Scaffold/Tech-Stack-Posture.md`
- `Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md`
- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`
- `M1` evidence package
- `M2` checkpoint evidence package

## Execution Packets

### Packet 1. Freeze The Canonical Runtime Contract

Outcome:

- one written contract exists for what moves from local-only truth to server
  truth

Work:

- define the minimum server-owned records
- define client-owned cached or derived state
- define migration constraints from the local checkpoint

Done when:

- the migration no longer depends on ad hoc decisions in implementation threads

### Packet 2. Build Phase-1 Runtime Persistence

Outcome:

- the server can persist the minimum collaboration runtime cleanly

Work:

- implement workspace, channel, workspace_persona, post, thread, message,
  post_participant, post_event, post_link, persona_activation, and agent_run
- implement the canonical runtime store on `Postgres`
- keep authored PersonaKit truth out of the server runtime schema

Done when:

- the canonical backend can store and replay the same core loop proven in `M2`

### Packet 3. Add Realtime Delivery

Outcome:

- client updates reflect server-backed truth instead of a second local source

Work:

- define event stream shape
- prefer `WebSocket` first; allow `SSE` only if it better preserves simplicity
  without weakening recovery guarantees
- implement subscriptions and replay entry points
- define failure behavior for dropped or stale clients

Done when:

- one client can reconnect and converge on canonical state deterministically

### Packet 4. Add Artifact Storage Abstraction

Outcome:

- posts and later workstreams have a durable artifact path without locking the
  system to one storage backend too early

Work:

- define object-style abstraction boundary
- keep the first backend self-hosted and filesystem-based, with a NAS-friendly
  posture
- keep the first implementation simple
- avoid coupling the first backend choice to the product model

Done when:

- artifacts can be referenced by stable identifiers and storage is replaceable

### Packet 5. Migrate The macOS Client

Outcome:

- the command-center remains believable while shifting to canonical server truth

Work:

- move read and write paths to the server
- preserve local UI quality from `M2`
- ensure activation trace semantics survive unchanged

Done when:

- the macOS client no longer acts as long-term owner of truth

### Packet 6. Prove Reliability And Replay

Outcome:

- the migration is trusted because replay, reconnect, and state convergence are
  tested

Work:

- run replay tests
- run reconnect and stale-state tests
- validate transaction and event ordering

Done when:

- the reliability and coverage owners can show canonical-state evidence instead
  of best-effort confidence

## Subagent Use Pattern

Safe subagents:

- schema and transaction design review
- stack-conformance review
- realtime transport spike
- client migration review
- replay and reconnect validation
- product continuity review

Avoid:

- parallel architecture changes that split canonical ownership across multiple
  services too early

## Evidence Package

- canonical runtime contract note
- stack-conformance review artifact
- schema and event model note
- canonical runtime boundary audit note
- phase-1 persistence bootstrap note
- realtime projection contract note
- realtime feed and replay service note
- database-backed replay loader note
- polling session recovery note
- transport adapter contract note
- artifact storage boundary note
- macOS cutover projection note
- replay and reconnect test results
- migration checklist for the macOS client
- architecture review artifact
- reliability review artifact
- product continuity review artifact
- migration validation artifact
- review packet

## Stop Points

- stop if the server begins mutating PersonaKit authored truth
- stop if client behavior diverges from canonical runtime semantics
- stop if the macOS room meaningfully regresses in Orbit-specific product clarity
- stop if implementation drifts away from `Swift + Vapor + Postgres` or introduces
  forbidden paid or extra-infrastructure dependencies
- stop before mobile-client work if replay and reconnect are not trusted

## Exit And Handoff

Exit when Orbit has one authoritative backend and the macOS client is a surface
over that truth.

Current disposition:

- AJ approved the current `M3` checkpoint as a trustworthy runtime-backbone
  review pass
- `M3` remains open until live gateway, live database proof, and macOS cutover
  work satisfy the full exit checklist

After `M3` closes, implementation pauses.

Do not begin `M4` or later construction until AJ explicitly restarts work beyond
`M3`.

Planned next milestones remain:

- `M4` and `M5` for richer collaboration behaviors
- `M11` and `M12` only after canonical runtime reliability is accepted
