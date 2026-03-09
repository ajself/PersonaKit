# SwiftUI Style Guide

# SwiftUI App Architecture Style Guide — Repo-Agnostic
*Feature-Oriented SwiftUI Architecture (FOSA): strict structure, pragmatic execution.*

## Purpose
- **Predictable ownership of mutable data**
- **Explicit mutation paths**
- **IO at the edges**
- **Minimal indirection**
- **Code readability for humans and coding agents**

**Related:** For Swift language conventions (UI and non-UI), see `SWIFT_STYLE_GUIDE.md`.

## Philosophy (descriptive)
- SwiftUI already provides a strong structural model; don’t fight it with unnecessary layers.
- The most important architectural question is: **who owns mutable data, and how is it changed?**
- Prefer **local clarity** over global abstraction.
- Optimize for “can a new person (or an agent) understand this in one pass?”

## Clarification: Not an ELM-style architecture

FOSA intentionally avoids ELM-style concepts such as reducers, unidirectional message dispatch, and explicit state/action/store triads.

While FOSA emphasizes clear ownership and explicit mutation, it does **not** prescribe:
- reducer-based architectures
- action enums or message passing
- centralized stores

Use explicit models or other clearly named owner types with well-defined responsibilities instead.

## Terminology & Rule Levels

This guide uses the following rule levels to communicate intent and enforcement:

- **Strict**  
  These rules are enforced. Deviations require an explicit `EXCEPTION(FOSA)` comment explaining why the rule does not apply.

- **Hybrid**  
  These sections define a strict default with intentional escape hatches. Follow the default unless it introduces more complexity than it removes.

- **Descriptive**  
  Guidance and best practices. Prefer these patterns, but use judgment where appropriate.

When in doubt, treat **strict** rules as non-negotiable, **hybrid** rules as defaults with justification, and **descriptive** rules as guidance.

---

## Non-negotiables (strict)
These rules are enforced. Deviations require a documented exception.

### 1) Ownership of mutable data MUST be single-owner
- Every mutable piece of data MUST have exactly **one owner**.
- Shared data MUST be explicitly hoisted (not accidentally duplicated).
- If two parts of the app can mutate the same concept, you MUST define a single owner and expose interaction through that owner’s explicit API.

**Anti-patterns**
- Two `@State` or `@Observable` objects representing the same mutable concept.
- Passing mutable state around as multiple bindings without a clear owner.

### 2) Mutation MUST be intentional and traceable
- Changes to owned data MUST happen through **named methods**, not scattered inline.
- A reader MUST be able to answer “what causes this to change?” by following 1–2 jumps.

**Prefer**
- `model.save()`
- other clearly named methods on an explicit owner type

**Avoid**
- Inline deep mutations across many views (`foo.bar.baz = ...` in random files)

### 3) IO MUST NOT happen in views
Views MUST NOT directly perform:
- Networking
- File IO
- Database reads/writes
- Keychain access
- OS services (workspace, notifications, pasteboard) except via a dedicated boundary

**Allowed**
- Triggering work through an owner type (model or other explicit owner) that delegates IO to a client/service.
- Lightweight UI-only tasks (animations, local formatting, UI measurement).

### 4) No default MVVM
- You MUST NOT create ViewModels by default “because architecture”.
- Introduce a coordinator/view-model-like type ONLY when it has a clear responsibility boundary:
  - cross-feature orchestration
  - non-trivial lifecycle management
  - complex derived state that does not belong to a single feature model or owner type

### 5) Architecture MUST be feature-oriented
- Code MUST be organized by **feature**, not by layer (e.g. not `Views/`, `ViewModels/`, `Models/` as primary structure).
- Layer folders are allowed **inside** a feature when helpful.

---

## Default project layout (strict)
Use this layout unless you have a clear reason not to.

```
Sources/
  App/
    AppRoot.swift
    AppEnvironment.swift (optional)
    Routing/ (optional)
  Features/
    <Feature>/
      Feature.swift (optional aggregator)
      <Feature>View.swift
      <Feature>Model.swift (optional)
      Components/ (feature-local UI)
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

### File naming (strict)
- Types and files MUST use consistent naming. Prefer `FeatureNameThing`.
- Feature entry types MUST be discoverable:
  - `<FeatureName>View`
  - `<FeatureName>Model` or another clearly named owner type

---

## Feature boundary model (hybrid)
Each feature has:
- **UI (SwiftUI view(s))**
- **Owner type** (explicit model or other clearly named owner)
- **Dependencies boundary** (clients/services used by the owner)

### Default: choose one owner shape (strict)
You MUST choose a clear, explicit owner type per feature and apply it consistently.

Most repos should default to an explicit model type (e.g. `FeatureModel`) that:
- owns mutable data
- exposes named methods for mutation
- coordinates async work

If a feature requires a different owner shape (e.g. coordinator, controller), it MUST be justified and documented.

### Architecture defaults (required)
Each repo MUST declare its architectural defaults in `App/ArchitectureDefaults.md`.
This file is intentionally small and should change rarely.

**Template (copy into `App/ArchitectureDefaults.md`):**

```md
# Architecture Defaults — FOSA

## Owner shape
**Default:** Explicit model (e.g. `FeatureModel`)

## Concurrency
- UI owner types are `@MainActor`
- Strict Swift concurrency checks are enabled

## Clients & IO
- All IO routed through Clients
- No IO in SwiftUI views

## Testing
- Tests required for non-trivial behavior
- Owner types are the primary unit under test
```

Agents MUST read this file before adding new features or owner types.

### Owned data is local by default (strict)
- Owned data MUST start local to the feature.
- Data MAY be hoisted only when:
  - two+ features truly share it
  - a parent feature owns the lifecycle
  - the UX demands single-source truth across screens

### Derived data should be computed, not stored (strict)
- If a value can be derived from other data, compute it unless:
  - it’s expensive and proven
  - it represents user input-in-progress
  - it is a cache with explicit invalidation rules

---

## View responsibilities (hybrid)

### Views MAY (descriptive)
- Render owned data
- Derive display-only values (formatting, presentation logic)
- Trigger actions on user interaction
- Use small view-local state for UI concerns (`@State` for toggles, focus, animation)

### Views MUST NOT (strict)
- Perform IO
- Own long-lived domain data without an explicit owner
- Become “coordination hubs” that glue multiple services together

### Rule of thumb (descriptive)
If you can’t test it without rendering the view, it probably belongs in the owner type.

---

## Exceptions (strict process, flexible outcomes)
Exceptions are allowed, but MUST be explicit.

### When an exception is valid (descriptive)
- The default pattern would introduce more complexity than it removes.
- SwiftUI framework constraints force a workaround.
- Performance constraints require deviation.

### How to take an exception (strict)
```swift
// EXCEPTION(FOSA): <one sentence why>.
// Default rule: <the rule name>.
// Tradeoff: <what we accept>.
```

---

## Dependencies & IO Boundaries (hybrid)

SwiftUI views define *what* the UI looks like.  
Owner types define *what happens*.  
Clients define *how the outside world is touched*.

This separation is non-negotiable for clarity, testability, and concurrency safety.

### Clients as the IO boundary (strict)
All interaction with the outside world MUST be routed through **Clients**:

- Networking
- File system
- Databases
- Keychain
- User defaults
- Notifications
- Pasteboard
- OS / application services

Clients are called by **owner types** (explicit models or coordinators), never directly by views.

### Client placement (strict)
- Reusable clients live in:
  - `Sources/Shared/Clients/`
- Feature-specific clients MAY live in:
  - `Sources/Features/<Feature>/Clients/`

If a client is used by more than one feature, it belongs in `Shared`.

### Client design (descriptive)
Prefer:
- Small, task-focused APIs
- Explicit method names (`loadProfile`, `saveDraft`, `exportGIF`)
- `async` / `async throws` APIs

Avoid:
- “Manager” or “Service” god objects
- Callback-based APIs unless required by legacy constraints
- Clients that hide threading or actor semantics

---

## Concurrency Model (Swift 6+) (hybrid)

Swift’s concurrency model is a **design constraint**, not an implementation detail.

The architecture must make concurrency *obvious* and *boring*.

### Owner types and the main actor (strict)
- Owner types that back SwiftUI views SHOULD be `@MainActor`.
- All UI-observable mutation MUST occur on the main actor.
- Cross-actor mutation is forbidden unless explicitly justified.

This keeps mental models simple and avoids accidental data races.

### Tasks and lifetimes (strict)
- Views MUST NOT launch tasks that perform IO.
- Async work is initiated by calling a method on the owner type.
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

Avoid:
- `Task.detached`
- Fire-and-forget background work
- Tasks without clear cancellation or ownership

### Cancellation (descriptive)
Long-running work SHOULD:
- Be cancellable
- Cancel previous work when replaced
- Be canceled on feature teardown or disappearance

Cancellation is part of correctness, not an optimization.

---

## Swift Concurrency Safety (Swift 6.x) (strict)

Certain concurrency escape hatches exist in Swift.  
They are **tools of last resort**, not everyday solutions.

### Code smells (strict)
The following are considered **code smells** and MUST NOT be used casually:

- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `Task.detached`

Repository policy override (PersonaKit): `@unchecked Sendable` is prohibited in all code and tests unless the repository owner gives explicit approval for the exact change. Approval records MUST be tracked in `Docs/PersonaKit/Architecture/unchecked-sendable-approvals.txt`.

`nonisolated(unsafe)` and `Task.detached` are allowed ONLY when:
- Ownership and lifetimes are fully understood
- No safer alternative exists
- The usage is localized
- An exception is documented

`@unchecked Sendable` remains prohibited unless the repository owner gives explicit approval for the exact change.

```swift
// EXCEPTION(FOSA): Required to bridge legacy C API that is externally synchronized.
// Default rule: Avoid @unchecked Sendable.
// Tradeoff: Compiler cannot verify thread safety; reviewed manually.
```

Prefer fixing:
- Ownership
- Actor isolation
- Data flow

over bypassing the concurrency model.

---

## SwiftUI Utilities & Modifiers (hybrid)

SwiftUI has sharp edges.  
When you hit one, **isolate it**.

### Modifier isolation (strict)
Framework workarounds MUST be encapsulated in:
- Reusable modifiers
- Small helpers
- Well-named utilities

Shared utilities live in:
- `Sources/Shared/UI/Modifiers/`

Feature-specific ones may live alongside the feature.

### Geometry and layout (descriptive)
Avoid scattering:
- `GeometryReader`
- Preference keys
- Layout hacks

Instead:
- See if a modifier or another option is available in SwiftUI.
- Create a reusable modifier or helper with clear intent
- Name it after *what it provides*, not *how it works*

Examples:
- `measureSize`
- `trackScrollOffset`
- `readSafeAreaInsets`

---

## Testing & Previews (hybrid)

Architecture exists to make behavior obvious and testable.

### Testing expectations (strict)
- Tests are **required** for non-trivial behavior.
- New or changed mutation logic MUST be accompanied by tests unless an explicit exception is documented.
- Bug fixes SHOULD include a regression test whenever practical.
- Follow `SWIFT_STYLE_GUIDE.md` for test style conventions and determinism guidance.

### Testing owner types (strict)
- Owner types SHOULD be testable without rendering views.
- Clients SHOULD be injectable and mockable.
- Async behavior SHOULD be testable deterministically.
- If behavior is difficult to test, treat this as a design signal to simplify ownership or boundaries.

### SwiftUI previews (descriptive)
- Previews are encouraged for visual validation.
- Previews SHOULD use mock clients and deterministic data.
- Avoid previews that depend on real IO or global state.

---

## Golden feature example (structure only)

This example shows the intended “happy path” layout and ownership boundaries for a typical feature.
It is intentionally code-free; the goal is to make file placement and dependencies obvious.

### Example: Profile feature

```
Sources/
  Features/
    Profile/
      ProfileView.swift
      ProfileModel.swift
      Components/
        AvatarView.swift
      Clients/
        ProfilePersistenceClient.swift (feature-local, if truly specific)
  Shared/
    Clients/
      APIClient.swift
      KeychainClient.swift
```

**Flow**
- `ProfileView` renders owned data and sends user intents to `ProfileModel`.
- `ProfileModel` owns mutable data and runs async work.
- `ProfileModel` calls Clients for IO (`APIClient`, `KeychainClient`, etc.).
- Clients encapsulate system / network / persistence details.
- Tests target `ProfileModel` with mocked Clients.

---

## Summary: How to decide where code belongs

Ask these questions in order:

1. Is this UI-only?
   → View or modifier
2. Does this change data or coordinate behavior?
   → Owner type
3. Does this touch the outside world?
   → Client
4. Does this feel hard to place?
   → The architecture is telling you something — simplify.

---

## Guiding principle (final)
**Structure first. Clarity second. Cleverness last.**

If a human or an agent can’t explain the flow in one pass, the design needs work.
