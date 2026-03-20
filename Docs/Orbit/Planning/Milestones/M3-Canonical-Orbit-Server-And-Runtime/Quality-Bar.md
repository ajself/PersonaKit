# M3 Quality Bar

Status: Accepted
Milestone: `M3`
Primary Owner: `studio-integration-coordinator`
Last Updated: 2026-03-18

## Purpose

Define what counts as impressive, review-worthy completion for the canonical
Orbit Server migration.

`M3` is where Orbit stops being a promising local proving surface and becomes a
real shared runtime. That means runtime truth, replay, and client-boundary
discipline are part of the milestone definition rather than optional
architecture polish.

## Non-Negotiable Standard

`M3` is reached only when Orbit has one authoritative server-backed runtime and
the macOS client behaves as a surface over that truth.

That means the milestone must be:

- canonical
- semantically faithful to `M1` and `M2`
- replayable and reconnect-safe
- explicit about ownership boundaries
- implemented inside the approved `Swift + Vapor + Postgres`, self-hosted,
  monolith-first posture
- evidence-backed rather than architecture-by-assertion

## Quality Attributes

### 1. Canonical Ownership

High bar:

- Orbit Server is the one runtime authority for the `M3` collaboration slice
- the macOS client no longer acts as long-term owner of posts, threads,
  messages, or activation-linked runtime state
- there is no hidden second truth path in local persistence or optimistic client
  logic

Failure signs:

- client state can diverge and still appear canonical
- local caches silently behave like authoritative runtime stores
- dual-write or fallback logic leaves ownership unclear

Evidence:

- `Canonical-Runtime-Contract.md`
- `Migration-Cut-Plan.md`
- architecture review artifact

### 2. Semantic Continuity

High bar:

- the server migration preserves the product semantics proven in `M1` and `M2`
- a server-backed room still feels like the same Orbit room, only more durable
  and authoritative
- activation trace semantics survive unchanged in meaning

Failure signs:

- migration changes what a post, thread, response, or trace means
- canonical backend work quietly weakens product clarity or attribution
- the server model breaks the local proving-loop behavior that was previously
  accepted

Evidence:

- `Golden-Canonical-Flow.md`
- migration validation results
- product review notes on semantic continuity

### 3. Authored Versus Runtime Boundary Fidelity

High bar:

- PersonaKit remains the source of authored contract truth
- Orbit Server stores runtime state, trace linkage, and execution records without
  mutating authored definitions
- contract snapshots are linked or persisted without turning the server into a
  second contract-authoring system

Failure signs:

- runtime schema tries to own persona policy
- server mutation is required to explain collaborator behavior
- authored and runtime truth blur inside migration code

Evidence:

- `Canonical-Runtime-Contract.md`
- architecture review artifact

### 4. Realtime Correctness

High bar:

- realtime events are projections of persisted state, not a second truth source
- the event model is small, useful, and reconstructible from durable records
- clients can reconcile by snapshot and replay rather than guesswork

Failure signs:

- events carry state that cannot be reconstructed from storage
- reconnect behavior depends on timing luck
- the event stream becomes the only place where some important transition exists

Evidence:

- `Failure-And-Recovery-Matrix.md`
- replay and reconnect validation results

### 5. Replay And Recovery Reliability

High bar:

- one client can disconnect, reconnect, and converge on canonical state
- partial failures do not fake durable success
- replay entry points and stale-state recovery are explicit and testable

Failure signs:

- a stale client can continue with incorrect assumptions
- replay gaps are papered over by local guesses
- a durable write failure still looks complete in the UI

Evidence:

- `Failure-And-Recovery-Matrix.md`
- reliability review artifact
- validation and review matrix results

### 6. Storage Boundary Discipline

High bar:

- transactional runtime truth stays in the database layer
- large durable file-like artifacts use an object-style storage abstraction
- the first backend choice remains implementation-simple without distorting the
  product model

Failure signs:

- artifact storage concerns leak into transactional semantics
- the first storage backend choice hardcodes future platform shape
- database and artifact responsibilities blur

Evidence:

- `Canonical-Runtime-Contract.md`
- `Decision-Register.md`

### 7. Migration Restraint

High bar:

- the migration path is staged and reviewable
- monolith-first remains binding unless AJ explicitly approves a change after
  reviewing evidence
- the milestone does not quietly absorb M4 or later concerns

Failure signs:

- service decomposition is introduced for taste rather than need
- meeting, workstream, or memory behavior broadens before the runtime backbone
  is trusted
- migration plans assume future clients before the macOS cutover is stable

Evidence:

- `Migration-Cut-Plan.md`
- `Decision-Register.md`

### 8. Evidence Quality

High bar:

- architecture, reliability, migration, and coverage evidence all exist
- reviewers can separate runtime correctness from product continuity and process
  quality
- milestone closeout depends on artifacts, not backend optimism
- when remote infrastructure is unavailable, a one-machine self-hosted proof on
  one Mac is acceptable so long as it uses the same approved `Swift + Vapor +
  Postgres` stack and a sharp closeout packet

Failure signs:

- server work is considered done because the code compiles
- replay and reconnect claims rely on implementer explanation rather than proof
- the branch is described as ready before the full review packet exists
- milestone closeout is blocked on unavailable CI or operations infrastructure
  even after the local self-hosted proof bar has been satisfied

Evidence:

- `Evidence-And-Exit-Criteria.md`
- closeout artifacts for architecture, reliability, validation, and migration

## Disqualifying Shortcuts

Any of these mean `M3` is not complete:

- the client can still behave as a second source of truth
- the server runtime mutates or re-owns PersonaKit authored contract truth
- the implementation drifts away from `Vapor`, `Postgres`, self-hosted private
  infrastructure, or the monolith-first posture without explicit AJ approval
- reconnect and replay behavior is not deterministic enough to defend
- event semantics cannot be derived from durable records
- the migration breaks `M1` and `M2` trace or room semantics
- the milestone broadens into later collaboration or multi-client features before
  canonical runtime truth is trusted

## What "Impressive" Looks Like

An impressive `M3` result means a reviewer can say:

- Orbit Server clearly owns runtime truth
- the macOS client remains product-strong after cutover
- state recovery works by design rather than luck
- activation and collaboration traces remain legible and faithful
- the backend became more authoritative without becoming more confusing

If the result only proves a server was added, it is not enough.
If the result proves Orbit now has one trustworthy runtime backbone, it is.
