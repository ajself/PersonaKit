# SwiftUI Style Guide

# SwiftUI App Architecture Style Guide — Repo-Agnostic

Feature-Oriented SwiftUI Architecture (FOSA): strict structure, pragmatic execution.

## Purpose

- Predictable ownership of mutable data
- Explicit mutation paths
- IO at the edges
- Minimal indirection
- Code readability for humans and coding agents

For Swift language conventions that apply outside UI work too, pair this with the Swift style reference.

## Philosophy

- SwiftUI already provides a strong structural model; do not fight it with unnecessary layers.
- The most important architectural question is who owns mutable data and how it changes.
- Prefer local clarity over global abstraction.
- Optimize for “can a new person or agent understand this in one pass?”

## Clarification: Not An ELM-Style Architecture

FOSA intentionally avoids reducer-first architectures, action enums, message dispatch, and centralized stores as defaults.
It emphasizes clear ownership and explicit mutation without forcing a store/action/reducer stack.

Use explicit models or other clearly named owner types with well-defined responsibilities instead.

## Rule Levels

- Strict: enforced rules that require an `EXCEPTION(FOSA)` comment to break
- Hybrid: strong defaults with intentional escape hatches
- Descriptive: guidance and best practices

## Non-Negotiables

### Single Ownership For Mutable Data

- Every mutable piece of data MUST have exactly one owner.
- Shared data MUST be explicitly hoisted, not accidentally duplicated.
- If two parts of the app can mutate the same concept, define a single owner and expose mutation through that owner’s named API.

### Mutation Must Be Traceable

- Changes to owned data MUST happen through named methods, not scattered inline.
- A reader SHOULD be able to answer “what causes this to change?” in one or two jumps.

Prefer:
- `model.save()`
- other clearly named methods on an explicit owner type

Avoid:
- inline deep mutations across many views

### No IO In Views

Views MUST NOT directly perform:
- networking
- file IO
- database reads or writes
- keychain access
- OS service access except through a dedicated boundary

Allowed:
- triggering work through an owner type that delegates to a client or service
- lightweight UI-only work like animation, formatting, or measurement

### No Default MVVM

- Do not introduce view models by default “because architecture.”
- Introduce a coordinator or view-model-like type only when it has a clear responsibility boundary, such as cross-feature orchestration or complex lifecycle management.

### Feature-Oriented Organization

- Organize code by feature, not by top-level layer buckets.
- Layer folders are fine inside a feature when they help.

## Default Project Layout

```
Sources/
  App/
    AppRoot.swift
    AppEnvironment.swift
    Routing/
  Features/
    <Feature>/
      <Feature>View.swift
      <Feature>Model.swift
      Components/
  Shared/
    UI/
      Components/
      Modifiers/
      Styles/
    Domain/
      Types/
      Validation/
    Clients/
      <Client>Client.swift
    Utilities/
Tests/
  Features/
  Shared/
```

### File Naming

- Types and files use consistent `FeatureNameThing` naming.
- Feature entry points should be easy to find, like `<FeatureName>View` and `<FeatureName>Model`.

## Feature Boundary Model

Each feature has:
- SwiftUI view(s)
- one explicit owner type
- client or service boundaries used by that owner

### Choose One Owner Shape

Most repos should default to an explicit model type that:
- owns mutable data
- exposes named methods for mutation
- coordinates async work

If a feature needs a different owner shape, document why.

### Architecture Defaults

Each repo should declare its architectural defaults in `App/ArchitectureDefaults.md`.
Agents should read that file before adding new features or owner types.

### Owned Data Starts Local

- Owned data starts local to the feature.
- Hoist only when multiple features truly share it or the parent owns the lifecycle.

### Derived Data Should Usually Be Computed

Compute derived values unless:
- it is proven expensive
- it represents user input in progress
- it is a cache with explicit invalidation rules

## View Responsibilities

### Views May

- render owned data
- derive display-only values
- trigger actions on interaction
- use small UI-local state for toggles, focus, or animation

### Views Must Not

- perform IO
- own long-lived domain data without an explicit owner
- become coordination hubs that glue services together

Rule of thumb: if you cannot test it without rendering the view, it probably belongs in the owner type.

## Exceptions

Exceptions are allowed, but they must be explicit:

```swift
// EXCEPTION(FOSA): <one sentence why>.
// Default rule: <the rule name>.
// Tradeoff: <what we accept>.
```

## Dependencies And IO Boundaries

Views define what the UI looks like.
Owner types define what happens.
Clients define how the outside world is touched.

### Clients As The IO Boundary

All interaction with the outside world should go through clients:
- networking
- file system
- databases
- keychain
- user defaults
- notifications
- pasteboard
- OS or application services

Clients are called by owner types, never directly by views.

### Client Placement

- Reusable clients live in `Sources/Shared/Clients/`
- Feature-specific clients may live in `Sources/Features/<Feature>/Clients/`

### Client Design

Prefer:
- small task-focused APIs
- explicit method names like `loadProfile`, `saveDraft`, `exportGIF`
- `async` and `async throws`

Avoid:
- god-object managers
- callback-heavy APIs unless legacy constraints require them
- clients that hide threading or actor semantics

## Concurrency Model

Swift’s concurrency model is a design constraint, not an afterthought.

### Owner Types And The Main Actor

- Owner types that back SwiftUI views SHOULD be `@MainActor`.
- UI-observable mutation MUST occur on the main actor.
- Cross-actor mutation is forbidden unless explicitly justified.

### Tasks And Lifetimes

- Views MUST NOT launch tasks that perform IO.
- Async work starts by calling a method on the owner type.
- Owner types own task lifetimes.

Prefer:

```swift
@MainActor
final class FeatureModel {
  private var loadTask: Task<Void, Never>?

  func load() {
    loadTask?.cancel()
    loadTask = Task {
      // async work
    }
  }
}
```

## Testing

- Tests are required for non-trivial owner behavior.
- Owner types are the default unit under test.
- When a feature needs a different architecture shape, document the reason and tradeoff.
