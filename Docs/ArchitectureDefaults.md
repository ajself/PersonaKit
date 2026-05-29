# Architecture Defaults - FOSA

PersonaKit follows Feature-Oriented SwiftUI Architecture (FOSA) with repo-local
defaults tuned for a deterministic developer tool. Agents must read this file
before adding features, state owners, IO boundaries, concurrency work, or FOSA
exceptions.

## Owner Shape

Default FOSA category: Observable Model.

Studio's official owner shape is:

```text
@MainActor @Observable WorkspaceStore
  + feature-scoped @MainActor Workspace*FeatureModel owners
  + explicit Studio Foundation / Shared Core clients and managers
```

This is the default for Studio, not accidental MVVM and not a reducer/store
architecture. Although the root owner is named `WorkspaceStore`, it is not the
FOSA Store + Action category.

- `WorkspaceStore` owns workspace selection, workspace-level presentation
  state, cross-feature coordination, and the feature-model graph.
- `Workspace*FeatureModel` types own bounded behavior such as loading,
  validation, library actions, session preview/map actions, editing, and system
  interaction.
- Do not create a second owner for the same mutable concept. Extend the
  existing owner through named methods, or stop and ask if the boundary is not
  clear.
- SwiftUI views render state and send user intent to `WorkspaceStore` or the
  appropriate feature model. Views do not become coordination hubs.
- Durable or cross-view mutable state belongs in `WorkspaceStore` or a
  feature-scoped owner. Truly local UI state may stay in a view.
- Mutations must be traceable through named methods on the owner type. Avoid
  scattered inline mutation of nested state from views.
- Derived values should be computed unless storing them is justified by user
  input-in-progress, caching with explicit invalidation, or measured cost.

Do not introduce default MVVM view models, reducers, action enums, generic
stores, or dependency-injection frameworks without explicit maintainer approval.

## Surface Map

PersonaKit is not only a SwiftUI app. Apply FOSA by surface:

| Surface | Default shape |
| --- | --- |
| Studio | `WorkspaceStore` plus feature-scoped `@MainActor` feature models. |
| Studio Foundation | Feature-local clients, managers, adapters, and state helpers used by Studio owners. |
| CLI | Command types with explicit `CLIEnvironment` / `CLIIO` boundaries. No SwiftUI owner required. |
| MCP | Deterministic read-only resource, prompt, and tool context. No writes or command execution. |
| Shared Context Core | Deterministic value types, resolvers, validators, loaders, and explicit file-system parameters. |
| Shared Workspace Core | Deterministic workspace managers/builders with explicit IO seams and stable ordering. |
| Site/docs/examples | Product explanation and release artifacts; preserve public behavior and deterministic examples. |

When a surface is outside SwiftUI, enforce FOSA's underlying rules: one owner for
mutable data, named mutation paths, IO at explicit boundaries, deterministic
ordering, and tests for non-trivial behavior.

## Clients And IO

IO belongs at explicit boundaries, never in SwiftUI views.

Studio views must not directly perform:

- file-system reads or writes
- UserDefaults reads or writes
- pasteboard access
- `NSWorkspace` / application service access
- notification, keychain, network, database, or process work

Allowed view behavior:

- render state
- derive display-only values
- hold local UI-only state such as focus, temporary field presentation,
  disclosure, selection, hover, animation, or layout state
- call named owner methods in response to user intent

IO should be routed as follows:

- Studio feature models may coordinate IO, but they should delegate the actual
  system or persistence work to named Studio Foundation or Shared Core
  boundaries.
- Studio-specific UI/system clients live under
  `Sources/Features/Studio/Foundation/` unless they become reusable.
- Reusable clients belong under `Sources/Shared/` in the relevant shared module.
- CLI IO belongs behind `CLIEnvironment`, `CLIIO`, or a similarly explicit
  command boundary.
- Shared Core and Workspace Core may accept `FileManager`, paths, clocks,
  clients, or other dependencies as explicit method or initializer parameters
  when that keeps deterministic code testable.
- MCP remains read-only context and provenance. It is not a write path, command
  runner, or workflow orchestrator.

Prefer small task-focused clients with method names that reveal the outside
world being touched. Avoid broad manager/service objects unless the existing
surface already owns a clearly named, tested responsibility.

## Concurrency

Swift concurrency safety is a design constraint for PersonaKit.

- UI-observable Studio owners are `@MainActor`.
- UI-observable mutation must happen on the main actor.
- Async work is initiated through an owner method, not by views performing IO.
- Owner types own task lifetimes and cancellation.
- Long-running or replaceable work must have an explicit cancellation strategy.
- Do not weaken Swift language mode or strict concurrency settings.
- Do not introduce `@unchecked Sendable`, `nonisolated(unsafe)`, or
  `Task.detached` as convenience fixes.

Concurrency escape hatches require explicit maintainer approval and a local
exception comment:

```swift
// EXCEPTION(FOSA): Required to bridge <specific reason>.
// Default rule: <rule being bypassed>.
// Tradeoff: <risk accepted>.
```

## Testing

Tests are required for non-trivial changes to:

- owner behavior and mutation paths
- IO-boundary behavior
- parsing, serialization, or schema behavior
- async task lifetime or cancellation behavior
- deterministic ordering
- public CLI, MCP, or example output
- bug fixes where a regression test is practical

Studio tests should target `WorkspaceStore`, feature models, Foundation clients,
or state helpers without rendering views whenever possible. CLI and shared-core
tests should use temporary roots and injected dependencies rather than real user
directories or global state.

Documentation-only changes may use lighter validation, but each session must
run the validation named by its tracker entry unless the maintainer explicitly
narrows the gate.

## Exceptions

FOSA exceptions are allowed only when the default would add more complexity than
it removes, a framework constraint forces a workaround, or a measured
performance/correctness constraint requires deviation.

Exception rules:

- Prefer changing ownership, isolation, or dependency boundaries before taking
  an exception.
- Keep exceptions local and narrow.
- Document Swift exceptions with `EXCEPTION(FOSA)` at the code site.
- Document documentation-only or planning exceptions in the tracker closeout.
- Include the default rule, reason, and tradeoff.
- Broad architecture, public behavior, execution, workflow, memory, or
  orchestration exceptions require maintainer approval before editing.

## Enforcement Checklist

Before changing an architecture-relevant surface, verify:

- Which owner owns each mutable value?
- Can each mutation be found through one or two named-method jumps?
- Does any view touch IO or system services directly?
- Are dependencies injected or otherwise obvious?
- Is async work owned and cancellable?
- Is derived data computed unless storage is justified?
- Are ordering and output deterministic?
- Are tests present for non-trivial behavior?
- Is any deviation documented as an approved `EXCEPTION(FOSA)`?

If the answer is unclear, stop and ask before expanding the design.
