# Canonical Runtime Contract

Status: Draft
Milestone: `M3`
Primary Owner: `architectural-editor`
Last Updated: 2026-03-18

## Purpose

Define the ownership boundary and minimum server contract for Orbit's first
canonical runtime.

This contract exists to prevent `M3` from becoming "add a server and hope the
boundaries sort themselves out later."

## Core Design Laws

### 1. Orbit Server Owns Runtime Truth

Orbit Server is the canonical owner of the `M3` collaboration runtime.

That includes:

- workspaces
- channels
- workspace persona instances
- posts
- threads
- messages
- post participants
- post events
- post links
- persona activations
- agent runs

### 2. PersonaKit Owns Authored Truth

PersonaKit remains the source of:

- personas
- directives
- kits
- skill authorization
- stop-point posture
- authored operating constraints

Orbit Server may link or snapshot resolved contract truth for runtime
traceability, but it must not become a parallel authored-definition system.

### 3. Clients Present State; They Do Not Finalize Truth

The macOS client may:

- fetch snapshots
- render current state
- queue requests
- show optimistic UI carefully when safe
- cache state for performance or resilience

The macOS client may not:

- finalize canonical post, thread, or activation truth independently
- resolve runtime conflicts by inventing server state
- behave as a durable second backend

### 4. Realtime Projects Durable State

Realtime is a projection of persisted state, not a second truth source.

That means:

- persisted transitions come first
- events reflect durable changes
- reconnect uses snapshot plus replay
- missing state is recovered from the server, not guessed locally

### 5. Monolith-First Still Applies

`M3` should preserve one deployable Orbit Server with logical service boundaries.

It should not introduce distributed service ownership unless AJ explicitly
approves that change after reviewing evidence.

AI lanes must not make that escalation on their own.

## Approved `M3` Stack Posture

For `M3`, the backend posture is not open-ended.

- implementation language: `Swift`
- server framework: `Vapor`
- canonical transactional runtime store: `Postgres`
- deployment posture: self-hosted and private
- preferred reference topology: `Mac mini + Synology`
- realtime posture: leaning `WebSocket`, `SSE` acceptable where it better serves
  the same semantics
- artifact storage posture: object-style abstraction over a self-hosted,
  filesystem-based backend with a NAS-friendly default direction

`M3` should also preserve these negative boundaries:

- no paid managed services in `M3`
- no extra infrastructure tiers such as `Redis`, `Kafka`, `NATS`, separate queue
  systems, or separate cache tiers unless AJ explicitly approves them later
- no Kubernetes, service mesh, or Docker-first deployment requirement

This posture exists so `M3` can focus on canonical runtime truth rather than
stack exploration.

It is binding implementation direction, not a menu for further server selection.

## Minimum `M3` Server-Owned Runtime Slice

The `M3` slice should cover the RFC-0002 phase-1 runtime set:

- `workspace`
- `channel`
- `workspace_persona`
- `post`
- `thread`
- `message`
- `post_participant`
- `post_event`
- `post_link`
- `persona_activation`
- `agent_run`

This is the minimum canonical backbone needed to preserve the Orbit proving loop
while preparing for later milestones.

## Minimum Client-Owned Non-Canonical State

The macOS client may own or cache:

- transient view state
- temporary composition state
- local selection state
- local snapshot cache
- queued requests only when explicitly modeled as non-canonical and not allowed
  to finalize truth without the server

The macOS client should not own:

- canonical roster truth
- canonical thread truth
- canonical message truth
- canonical activation or run truth

## Contract Snapshot Rule

For server-backed participant responses, the system must preserve inspectable
linkage to resolved contract truth.

That linkage may be:

- a durable contract snapshot reference
- a durable activation-linked record that points to the resolved contract inputs

What matters is that the server runtime can explain why a response happened
without pretending the server authored the contract.

## Database Versus Artifact Storage Rule

Transactional collaboration truth belongs in the relational data store.

Large file-like durable artifacts belong behind an object-style storage
abstraction.

The first backend may be simple, but the abstraction must not hardcode the first
storage implementation into the product model.

## Migration Rule

The migration from `M2` local truth to `M3` canonical truth should preserve
product semantics while removing long-term dual truth.

That means:

- seeded fresh server state or a re-proven server-backed flow should be the
  default
- historical import of local proving-loop data should not be the default path
- long-lived dual-write should be avoided
- any temporary transitional path must be explicit, auditable, and time-bounded

## Disallowed Shortcuts

Do not:

- store authored PersonaKit policy as if Orbit Server owns it
- make the event stream the only durable source for an important transition
- let the macOS client continue owning canonical runtime data after cutover
- introduce service splits merely to look platform-like

## Quality Rule

This contract is only good enough for `M3` if a reviewer can use it to detect
boundary drift before code and infrastructure harden around the wrong model.
