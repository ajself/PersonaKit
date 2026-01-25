# SwiftUI App Style Guide (Codex + PM Review) — v5
*A repo-agnostic guide for SwiftUI iOS + macOS apps, designed for humans and agents.*

This document is meant to be:
- **Simple enough for humans** to follow.
- **Strict enough for agents (Codex)** to implement and review against.
- **Platform-agnostic** across iOS and macOS, with small notes where behavior differs.

---

## Language and toolchain settings (Swift 6.2 + Approachable Concurrency)

These are **default recommendations** for new SwiftUI iOS/macOS apps. Adjust if you have legacy constraints.

### Swift version
- Target **Swift 6.2**.
- Prefer the Swift 6 language mode when feasible; otherwise, move incrementally while keeping concurrency checks enabled.

### Approachable Concurrency defaults
Approachable Concurrency is about making concurrency safer *without* forcing you to annotate everything at once.

Principles:
- Treat **UI state** and **SwiftUI-facing models** as main-actor isolated by default.
- Push concurrency complexity to **clients and workers**.
- Add `Sendable` and isolation annotations where they clarify boundaries and prevent mistakes.

### Concurrency checking strategy (pragmatic)
Use a “ratchet” approach: enable checks broadly, then tighten over time.

**Recommended build settings (Xcode):**
- Swift Compiler – Concurrency:
  - **Strict Concurrency Checking**:
    - Existing apps: **Minimal** or **Targeted**
    - New apps/modules: **Complete**
  - Prefer warnings-as-errors for new modules.

### Practical rules
- Any SwiftUI-observed type must be:
  - `@MainActor` if it mutates UI state
  - `@Observable` (or `ObservableObject`)
- Async functions touching UI state must run on the main actor.
- Avoid capturing non-sendable state in detached tasks.

---

## Linting and Formatting

Linting and formatting are **part of the architecture**, not optional tooling.

### Formatting (Authoritative)
- Use **`swift-format`** as the canonical formatter.
- Formatter output is considered correct by definition.
- Formatting should be applied automatically (editor, pre-commit, or CI).

### Linting (Opinionated and Curated)
- Enforced via **SwiftLint** with a curated ruleset.
- Linting reinforces architectural intent and prevents footguns.
- Disabling a rule requires a comment explaining why.

**Enforcement posture**
- Formatting violations block commits.
- Lint violations block PRs unless explicitly justified.

**Line length policy**
- `swift-format` lineLength=100 is authoritative.
- SwiftLint limits are guardrails for legacy or unformatted code; new code should stay at 100.

---

## Philosophy

- **SwiftUI-first composition.** Views are thin; logic lives elsewhere.
- **Single source of truth.** Each concern has one owning state object.
- **Navigation as data.** Routes are modeled, not pushed ad hoc.
- **Explicit concurrency.** Async work is visible, cancellable, and isolated.
- **IO isolation.** File/network/database work never lives in views.
- **Errors are states.** Failure is modeled and rendered intentionally.

---

## Dependency Management (Required)

This architecture uses **pointfreeco/swift-dependencies** to control dependencies for:
- fast, deterministic tests
- reliable previews
- avoiding direct access to "outside world" APIs

**Rules**
- Feature/store logic must not directly call:
  - `Date()`, `Date.now`, `UUID()`, `Task.sleep`, clocks/timers, schedulers/queues
  - global singletons for system services (unless wrapped)
- Instead, dependencies must be accessed via `@Dependency` and overridden in tests/previews.

**How**
- Declare dependencies as properties using `@Dependency(...)`.
- Mark those properties as `@ObservationIgnored` in `@Observable` types to avoid observation churn.
- Override dependencies in tests using `withDependencies { ... } operation: { ... }`.
- Override dependencies in previews using `prepareDependencies { ... }`.

**Version**
- Pin `swift-dependencies` with SwiftPM and treat `Package.swift` / `Package.resolved` as source of truth. Avoid “latest” language in docs.

---

## Unidirectional Data Flow (Required)

Feature-level unidirectional data flow is required.

Rules:
- State mutations occur in one place.
- Views send actions; they never mutate state directly.
- Async work is triggered by actions and is cancellable.

Each feature defines:
- `State`
- `Action`
- `Store` with `send(_:)`

---

## Effects and Async Work

Async work is considered an **effect**.

Rules:
- Effects are triggered by actions, never directly from views.
- Effects must be cancellable if user intent can change.
- Effects must not mutate state directly.

Detached tasks that mutate shared state are discouraged.

---

## Internal Architecture Module (Per App)

Each app owns a small, internal Architecture layer.

Purpose:
- Enforce UDF mechanically
- Centralize concurrency and cancellation
- Reduce boilerplate
- Provide a predictable model for agents

Suggested location:
```
App/Architecture/
```
or
```
Packages/Architecture/
```

Keep this module small and boring. Avoid macros and heavy DSLs initially.

---

## Package Composition and Boundary Enforcement (Required)

Boundaries must be enforced structurally, not just by convention.

This guide requires **module boundaries enforced by Swift Packages (SwiftPM)**.

### Banned structures
- Do not rely on Xcode folders as boundaries.
- Do not create globally importable grab-bag directories.
- Do not let the app target become an architectural dumping ground.

### Required module structure (example)

```
AppShell/
Packages/
  Package.swift
  Sources/
    Architecture/
    Env/
    UIComponents/
    Networking/
    Persistence/
    Domain/
    Features/
      FeatureA/
      FeatureB/
  Tests/
```

### Repository mapping (keep current)
When applying this guide to a specific repo, include a short mapping section and keep it updated with rebrands. Example for this repo:

- AppShell: `Sources/PersonaKitApp`
- Core: `Sources/PersonaKitCore`
- CLI: `Sources/PersonaKitCLI`
- Resources: `Sources/PersonaKitResources`
- Schema validation: `Sources/PersonaKitSchemaValidate`

Keep this list in sync with the repo tree; do not leave stale product names.

### Dependency direction rules
- `AppShell` → Features + shared modules
- `Features/*` → Architecture, Env, UIComponents, Networking, Persistence, Domain
- Shared modules must not depend on Features
- Features must never import other Features directly

Default to `internal`. Minimize `public` APIs.

---

## Dependency and Boundary Rules

- Views → Stores only
- Stores → Clients/Workers + pure helpers
- Clients/Workers → system frameworks only (and controlled dependencies)
- Architecture/shared code → no feature imports

Shared state must have a single owner.

---

## Networking Conventions

- All networking goes through typed clients.
- Clients return typed values or throw typed errors.
- Retry/auth logic lives in one place.
- Caching strategy must be explicit and testable.
- Any system time/UUID/backoff/timers used by networking should be dependency-controlled.

---

## Observability and Logging

- Use structured logging (`OSLog` or equivalent).
- Never log secrets or personal data.
- Errors reaching UI state must be logged with context.
- Measure long-running or failure-prone operations.

Observability code must not leak into views.

---

## Accessibility and Localization Requirements

Accessibility and localization are engineering responsibilities.

- Custom controls require accessibility labels and hints
- Dynamic Type must not catastrophically break layouts
- macOS features must consider keyboard and focus behavior
- User-facing strings must be localizable

Accessibility regressions block shipping.

---

## Refactoring Guidance

Refactoring is expected and encouraged, but it must be **safe**, **incremental**, and **boundary-respecting**.

### Refactoring principles
- Prefer small refactors with clear wins over large rewrites.
- Refactor to improve boundaries, UDF, concurrency correctness, and testability.
- Avoid mixing refactors with behavior changes unless explicitly stated.

### Safety rules
Before refactoring:
- Ensure baseline tests or define a manual test plan.

During refactoring:
- Keep one refactor theme per PR.
- Do not casually move code across module boundaries.

After refactoring:
- Verify linting and formatting are clean.
- Verify cancellation and main-actor isolation still hold.
- Verify logging and error states are not degraded.

---

## Store Template (swift-dependencies)

```swift
import Dependencies
import Observation

@MainActor
@Observable
final class FeatureStore {

  struct State {
    var loadState: LoadState<[Item]> = .idle
  }

  enum Action {
    case task
    case refresh
    case retry
  }

  private(set) var state = State()
  private var task: Task<Void, Never>?

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock

  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  @ObservationIgnored
  @Dependency(\.date.now) var now

  @ObservationIgnored
  @Dependency(FeatureClient.self) var client

  func send(_ action: Action) {
    switch action {
    case .task, .refresh, .retry:
      load()
    }
  }

  private func load() {
    task?.cancel()
    task = Task {
      state.loadState = .loading
      do {
        // Example: use dependency-controlled time if needed
        // try await clock.sleep(for: .milliseconds(50))

        let items = try await client.fetchItems()
        state.loadState = .loaded(items)
      } catch {
        state.loadState = .failed(error)
      }
    }
  }
}
```

### Testing template (override dependencies)

```swift
import Dependencies
import Testing

@Test
func loadsItems() async throws {
  let store = withDependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSinceReferenceDate: 1234567890)
    $0.continuousClock = .immediate
    $0[FeatureClient.self] = .mock(items: [.init(id: UUID(), name: "A")])
  } operation: {
    FeatureStore()
  }

  store.send(.task)
  // Assert on store.state...
}
```

### Preview template (override dependencies)

```swift
import Dependencies
import SwiftUI

#Preview {
  let _ = prepareDependencies {
    $0.continuousClock = .immediate
    $0[FeatureClient.self] = .preview
  }

  return FeatureView(store: FeatureStore())
}
```

---

## Pull Request Checklist (Required)

Every PR must satisfy the following:

- [ ] Code is formatted with `swift-format`
- [ ] No new SwiftLint warnings (or justified inline)
- [ ] Feature uses UDF (`State` + `Action` + `send`)
- [ ] Views do not mutate state or perform async work
- [ ] Effects are cancellable where appropriate
- [ ] Dependencies are controlled (no direct `Date()`, `UUID()`, `Task.sleep`, etc.)
- [ ] Module boundaries are respected
- [ ] Networking uses typed clients
- [ ] Errors are modeled and logged
- [ ] Accessibility and localization considered
- [ ] Refactors are scoped and safe

Unchecked items represent architectural debt and must be acknowledged.

---

## When It’s Acceptable to Break These Rules

Breaking a rule is acceptable when:
- the feature is trivially small
- complexity would be disproportionate
- performance constraints require deviation

Requirements:
- document the reason
- scope the exception tightly
- avoid pattern propagation

---

## PM Review Lens

Use this to review shippability:

- Are core flows clear?
- Are error states actionable?
- Is performance appropriate?
- Are accessibility basics covered?
- Is the code maintainable and testable?
