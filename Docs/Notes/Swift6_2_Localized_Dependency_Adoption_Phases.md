## Swift 6.2 Localized Dependency Resolution: Phased Adoption

Goal: Resolve dependencies locally (per method or short-lived scope) using
swift-dependencies, avoiding stored `@Dependency` properties on long-lived
`@Observable` types. Each phase ends with a review checkpoint before proceeding.

Status:
- Phase 1 complete: CLI/schema/pack diff fallbacks use localized resolution.
- Phase 2 complete: AppModel + SidebarModel migrated; stored `@Dependency` removed.
- Phase 3 complete: Core helpers use localized resolution; DependencyAccess shim removed.
- Phase 4 complete: added storage-path defaults and dependency fallback tests.
- Phase 5 complete: adopt local `@Dependency` variables for localized resolution.

## Inventory (Phase 0 Notes)
Captured before migrations; see Status for completion state.

### Stored `@Dependency` sites
- `Sources/PersonaKitCLI/PersonaKitCLIMain.swift`: `CLIEnvironment` uses
  `@Dependency(\.fileClient)` once in `main`.
- `Sources/PersonaKitSchemaValidate/PersonaKitSchemaValidateMain.swift`:
  `SchemaEnvironment` uses `@Dependency(\.fileClient)` once in `main`.
- `Sources/PersonaKitCore/Dependencies/DependencyAccess.swift`:
  `FileClientProvider` uses `@Dependency(\.fileClient)` as a fallback.
- `Sources/PersonaKitApp/App/Model/AppModel.swift`:
  `@Dependency(\.fileClient)`, `@Dependency(\.appClient)`,
  `@Dependency(\.uuid)`, `@Dependency(\.continuousClock)`.
- `Sources/PersonaKitApp/Features/Inspector/PackDiffInputBuilder.swift`:
  `PackDiffEnvironment` uses `@Dependency(\.fileClient)` as a fallback.
- `Sources/PersonaKitApp/Features/Sidebar/SidebarModel.swift`:
  `@Dependency(\.uuid)` for focus tokens and saved filter IDs.

### Primary access points
- `AppModel` extensions: composer focus, import/reveal, reload, inspector, JSON
  preview debounce.
- `SidebarModel`: focus requests and saved filter IDs.
- `PackDiffInputBuilder`: fallback file client in `build(...)`.
- Core helpers: `FileClientProvider` fallback in pack load/locate/storage paths.

### Phase 0: Inventory and Scope
- List all types that store `@Dependency` properties.
- Note which dependencies are used in each type and where they are accessed.
- Identify any call sites that can use local resolution without changing API
  surface.

Review checkpoint: confirm the inventory list and decide which types to migrate
first.

### Phase 1: Small, Safe Conversions
- Convert the lowest-risk `@Dependency` usages to local resolution (inside
  methods) in a single target.
- Keep behavior identical; no API changes outside the type.
- Add small, focused tests if needed to guard behavior.

#### Phase 1 candidate examples (no code changes yet)

CLI before:
```swift
private struct CLIEnvironment {
  @Dependency(\.fileClient) var fileClient
}

let fileClient = CLIEnvironment().fileClient
```

CLI after (localized resolution):
```swift
@Dependency(\.fileClient) var fileClient
```

Schema validate before:
```swift
private struct SchemaEnvironment {
  @Dependency(\.fileClient) var fileClient
}

let fileClient = SchemaEnvironment().fileClient
```

Schema validate after (localized resolution):
```swift
@Dependency(\.fileClient) var fileClient
```

PackDiffInputBuilder before:
```swift
let fileClient = fileClient ?? PackDiffEnvironment().fileClient
```

PackDiffInputBuilder after (localized resolution):
```swift
@Dependency(\.fileClient) var resolvedFileClient
let fileClient = fileClient ?? resolvedFileClient
```

Review checkpoint: verify the changes are minimal and no behavioral drift.

### Phase 2: Core UI Model Migration
- Migrate `AppModel` and other long-lived `@Observable` types to local resolution
  at call sites.
- Remove stored `@Dependency` properties from those types.
- Keep dependency access explicit in the methods that actually use them.

Review checkpoint: verify sendability warnings are gone and UI behavior is
unchanged.

### Phase 3: Consolidate Patterns
- Standardize on a local-resolution pattern (e.g., local `let` bindings inside
  methods).
- Update team conventions or documentation if needed.
- Remove any legacy helper shims added during earlier phases.

Completed in Phase 3:
- Replaced `FileClientProvider` usage in PersonaKitCore with localized file
  client resolution.
- Added `DependencyValues.current` shim in PersonaKitCore and removed
  `DependencyAccess.swift`.

Review checkpoint: confirm the pattern is consistent and still minimal.

### Phase 4: Tests and Regression Coverage
- Add targeted tests for any behavior that was previously implicit in stored
  dependencies.
- Ensure CLI and app parity remains intact.

Completed:
- Added storage-path defaults coverage for dependency-driven home directory
  resolution.
- Added tests for dependency fallback in import planning, user pack loading, and
  pinned personas default path.
- Verified PersonaKitCore tests pass via shared macOS scheme.

Review checkpoint: confirm tests cover the intended behaviors and no new
dependencies were introduced.

### Phase 5: Optional Local `@Dependency` Style Review
- Apply local `@Dependency` variables inside methods for consistency and
  readability.
- Decide whether to keep `DependencyValues.current` shim available for future
  use or remove it once the migration is complete.

Review checkpoint: agree on the preferred localized style before finalizing.

Working notes:
- Preferred localized style: local `@Dependency` variables inside methods.
- Spike: `AppModel.requestComposerFocus` uses local `@Dependency`; PersonaKitApp
  builds cleanly with Swift 6.2.
- Exception: `AppClient` access remains `DependencyValues.current.appClient`
  in `AppModel+ImportReveal` because local `@Dependency(\.appClient)` triggers a
  Swift 6.2 Sendable key path error; revisit when swift-dependencies updates or
  compiler behavior changes.
