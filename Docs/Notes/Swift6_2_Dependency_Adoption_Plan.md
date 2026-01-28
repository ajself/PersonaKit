## Swift 6.2 KeyPath Sendability: Option 3 Summary

### What Option 3 Is
Avoid storing `@Dependency` properties on long-lived `@Observable` types.
Instead, resolve dependencies at the composition root and pass concrete values
into initializers.

### Why It Helps
- The error is triggered by `@Dependency(\.appClient)` itself.
- The property wrapper holds a `WritableKeyPath`, and Swift 6 treats that key path
  as non-`Sendable`.
- If `@Dependency` is not stored on the observable type, the compiler no longer
  has to prove that key path is sendable.

### Sketch (structure only)
```swift
@MainActor
@Observable
final class AppModel {
  let fileClient: FileClient
  let appClient: AppClient
  let uuid: UUIDGenerator
  let clock: AnyClock<Duration>

  init(
    fileClient: FileClient,
    appClient: AppClient,
    uuid: UUIDGenerator,
    clock: AnyClock<Duration>,
    savedFiltersStore: SavedFiltersStore = .init(),
    pinnedPersonasStore: PinnedPersonasStore = .init()
  ) {
    self.fileClient = fileClient
    self.appClient = appClient
    self.uuid = uuid
    self.clock = clock
    ...
  }
}
```

### Where Dependencies Come From
- Resolve once at the composition root (app entrypoint) and pass values in.
- Tests can pass explicit test doubles without `withDependencies`.

### Pros
- Cleanly avoids `WritableKeyPath` sendability issues.
- Dependencies are explicit and deterministic.
- Test setup is straightforward (pass mocks into init).

### Cons
- Less ergonomic than `@Dependency` inside the type.
- Requires threading dependencies through initializers (or a small container).

## Prospective Plan (Option 3)

1. Identify long-lived `@Observable` types that store `@Dependency` properties.
2. Convert those `@Dependency` properties to plain stored values.
3. Update initializers to accept those dependencies explicitly.
4. Build the dependency values in the app entrypoint (composition root) and pass
   them into initializers.
5. Update tests to inject explicit dependencies instead of using
   `withDependencies`.

