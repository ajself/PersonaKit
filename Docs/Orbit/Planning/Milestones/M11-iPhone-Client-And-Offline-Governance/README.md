# M11 iPhone Client And Offline Governance

Status: Planned
Primary Owner: `senior-swiftui-engineer`
Supporting Personas: `studio-reliability-engineer`, `venture-product-steward`, `studio-coverage-architect`
Last Updated: 2026-03-18

## Purpose

Extend Orbit to quick interaction and approvals without creating a second truth
system.

## Preconditions

- `M3` canonical server runtime is trusted
- mobile use cases are explicitly narrowed to high-value phone workflows
- offline policy is defined before implementation begins

## Scope Freeze

In scope:

- iPhone client
- notifications
- local draft queue
- offline intent handling
- reconnect reconciliation for approvals and sends

Out of scope:

- feature parity with the macOS client
- local-first forked data ownership
- silent approval reconciliation

## Required Inputs

- `Docs/Orbit/RFCs/RFC-0006-Orbit-Multi-Client-Platform-Architecture.md`
- `M3` canonical runtime evidence
- any later product brief that narrows the phone use-case wedge

## Execution Packets

### Packet 1. Freeze The Phone Use-Case Wedge

Outcome:

- the phone client is optimized for the right jobs instead of copying desktop UI

Work:

- define top phone workflows
- define what must remain desktop- or tablet-only
- define approval, notification, and quick-reply boundaries

Done when:

- implementation does not drift into broad desktop parity

### Packet 2. Build The Core Client Shell

Outcome:

- the iPhone app supports the narrow high-value Orbit loop cleanly

Work:

- build core navigation and client shell
- connect to canonical server state
- preserve shared runtime semantics with other clients

Done when:

- one useful mobile workflow can be performed without semantic drift

### Packet 3. Add Notifications And Approval Surfaces

Outcome:

- time-sensitive actions can be surfaced and handled quickly on phone

Work:

- add notification entry points
- add approval surfaces
- define stale-state warnings and blocked states

Done when:

- approvals are convenient without becoming under-reviewed

### Packet 4. Add Draft Queue And Offline Intent Handling

Outcome:

- temporary disconnection does not create a second truth source

Work:

- add local draft queue
- define send and approval intents while offline
- define what cannot be completed offline

Done when:

- client behavior during disconnection is explicit and bounded

### Packet 5. Prove Reconnect Reconciliation

Outcome:

- the phone client can rejoin canonical state safely

Work:

- run stale-client tests
- run reconnect tests
- verify approval reconciliation and conflict handling

Done when:

- the reliability owner signs off on offline and reconnect behavior

## Subagent Use Pattern

Safe subagents:

- mobile wedge review
- offline-state review
- reconciliation review
- reliability validation review

Avoid:

- parallel client behavior changes that diverge from canonical runtime semantics

## Evidence Package

- mobile use-case brief
- notification and approval examples
- offline intent matrix
- reconnect validation results
- reliability review artifact

## Stop Points

- stop if the phone app becomes a second source of truth
- stop if offline approval behavior is ambiguous
- stop if mobile convenience weakens review gates

## Exit And Handoff

Exit when the iPhone client supports quick interaction and approvals while still
deferring to canonical server truth.

Handoff forward to:

- `M12` and `M13` as broader platform maturity work continues
