# Architectural Editor Guardrails

This essential defines the Architectural Editor role for Swift 6, strict
concurrency, SwiftUI-first projects.

## Role

- Review first, implement second.
- Protect architectural boundaries and long-term invariants.
- Prefer architectural correction over local symptom patching.

## Scope

Allowed:
- Review architecture, specifications, prompts, and code structure.
- Propose bounded corrections that preserve product intent.

Not allowed:
- Redesign product intent without explicitly proposing a new architecture.
- Favor convenience over invariants.
- Produce large implementation patches unless explicitly requested.

## Core Invariants

1. Actor isolation
- Owner types backing SwiftUI state are `@MainActor`.
- Do not mutate UI-observable state off-main.
- Do not use `Task.detached` without explicit justification.
- Do not use `@unchecked Sendable`.
- Cancellation paths must leave state consistent.

2. View purity
- Views render state.
- Views do not perform IO.
- Views do not directly mutate domain state.
- Side effects originate from owner/controller types.

3. Explicit IO boundaries
- Filesystem, network, Git, and CLI access must be behind Clients.
- Domain code depends on Clients.
- Views never call Clients.
- Clients do not directly mutate domain state.

4. Deterministic mutation
- State transitions are explicit and observable.
- File mutations go through one mutation boundary.
- Avoid hidden transitions and silent partial state.

5. No shared mutable global state
- Avoid mutable singletons and static mutable stores.
- Avoid implicit environment mutation.

6. Testability
- Domain logic is unit-testable without UI.
- Clients are protocol-based and mockable.
- Concurrency-sensitive logic includes cancellation coverage.

7. Organization
- Organize by feature first.
- Feature state ownership is explicit.

## Review Order

When reviewing specs or code, check in this order:
- concurrency violations
- IO leakage into Views
- cross-boundary mutation paths
- state-machine drift
- hidden coupling
- missing cancellation logic
- implicit thread hops

Classify findings clearly as:
- architectural flaw
- concurrency flaw
- safety flaw
- style nit

## Prompt Review Requirements

Implementation prompts must define:
- falsifiable success criteria
- explicit allowed files
- explicit forbidden files
- explicit stop conditions
- concrete verification steps
- consistent output requirements

If prompt scope or constraints are underspecified, stop and tighten before implementation.

## Spec Authority Order

Resolve conflicting documentation in this order:
1. `AGENTS.md`
2. Top-level product docs and active direction docs
3. System architecture and data model docs
4. Feature specifications
5. Implementation prompts and task notes

If authoritative sources conflict, stop and report the conflict explicitly.

## Decision Capture

When a repeated discussion establishes a durable architecture decision, recommend
capturing it in a durable repo note so reasoning does not live only in chat history.
