# Orbit First Checkpoint Runtime Model

Status: Draft
Owner: Samwise
Workspace: Orbit
Last Updated: 2026-03-09

## Purpose

Define the minimum durable runtime model and persistence boundary for Orbit's
first engineering checkpoint.

This note exists so the first build can stay aligned on:

- what must be durable now
- what can remain lightweight or derived
- where activation trace begins
- what should not enter the first checkpoint yet

## Checkpoint Scope

This runtime note covers only the first execution checkpoint defined in
`Orbit-Execution-Plan.md`:

1. workspace and roster foundation
2. durable conversation loop
3. minimal lightweight meeting and activation trace behavior

It does not yet define:

- summary storage
- memory candidate storage
- approved memory reuse
- cross-workspace entities
- deep squad or team modeling

## Founding Assumptions

For the first checkpoint, Orbit should assume:

1. one local workspace: `Orbit`
2. one founding roster: AJ, Samwise, ProdDoc
3. one durable conversation thread is enough to prove the loop
4. meeting behavior can be represented as a lightweight interaction mode over
   the same underlying thread model
5. activation trace must be durable from day one even if the UI is minimal

## Minimum Runtime Entities

### Workspace

Represents the operating boundary for the Orbit command center.

Must include:

- stable workspace identifier
- display name
- short purpose or description
- founding participant IDs
- current active thread ID

Can remain out of scope for now:

- multiple workspace switching
- workspace settings surface
- team or squad hierarchy

### Participant

Represents a visible durable collaborator in the workspace.

Must include:

- stable participant identifier
- display name
- participant type or role label
- linked persona ID when the participant is AI-backed
- availability or active-state hint suitable for UI display

For the first checkpoint:

- AJ may be represented as a human participant record
- Samwise and ProdDoc should be represented as durable AI-backed participants

### Conversation Thread

Represents the durable discussion container.

Must include:

- stable thread identifier
- workspace identifier
- title or lightweight label
- ordered message IDs
- created/updated markers suitable for deterministic local ordering
- current interaction mode:
  - direct message
  - lightweight meeting

For the first checkpoint, a single active thread is enough as long as it is
durable across restart.

### Message

Represents one visible turn in the conversation surface.

Must include:

- stable message identifier
- thread identifier
- speaker participant identifier
- message body
- ordered position within the thread
- message kind:
  - user
  - participant-response
  - system-event
- optional reply-to or trigger linkage when needed for attribution

The first checkpoint does not need advanced edit history or branching
conversation structure.

### Activation Record

Represents why a participant response happened.

Must include:

- stable activation identifier
- response message identifier
- participant identifier
- persona identifier
- directive identifier
- trigger source:
  - direct address
  - meeting invocation
  - general thread reply
- trigger message identifier when applicable
- memory-influenced flag

This entity is the minimum explainability boundary for the first checkpoint.

## Persistence Boundary

The first checkpoint should persist:

1. workspace record
2. participant records
3. conversation thread record
4. messages
5. activation records

The first checkpoint may keep these derived at runtime:

1. roster ordering for display
2. active-speaker highlighting
3. lightweight meeting state if it can be reconstructed from the thread plus
   recent activation records

The first checkpoint should not persist yet:

1. memory candidates
2. summaries
3. approval workflows beyond the visible conversation loop
4. speculative analytics

## Local Persistence Recommendation

The smallest acceptable persistence approach for this checkpoint should be:

1. local-only
2. deterministic
3. easy to inspect during development
4. simple to evolve into richer storage later

A reasonable first choice is one small local store that can write and reload:

- workspace
- participants
- threads
- messages
- activation records

The specific storage technology should be chosen for implementation simplicity,
not long-term platform ambition.

## UI Mapping For The First Build

The first macOS shell should map these entities directly:

1. workspace record
   Drives workspace header and context surface.
2. participant records
   Drive founding-group roster visibility and speaker identity.
3. thread record plus messages
   Drive the primary conversation surface.
4. activation records
   Drive the lightweight trace affordance for participant responses.

If a visible UI element cannot be traced back to one of these entities, it is
probably too early for the first checkpoint.

## Guardrails

- Do not introduce team, squad, or memory entities into this checkpoint model.
- Do not let meeting orchestration become a parallel data model if a thread plus
  activation records can express the behavior.
- Do not treat activation trace as optional metadata.
- Do not optimize for multi-client sync before the local loop is real.

## Immediate Follow-On

After this note, the next implementation-planning artifact should map the first
checkpoint into files or modules, using these entities as the boundary.

## Revision Notes

- 2026-03-09: Initial Samwise runtime-model note created to support the first
  Orbit execution checkpoint defined in `Orbit-Execution-Plan.md`.
