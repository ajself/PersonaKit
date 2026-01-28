## Swift 6.2 Localized Dependency Resolution: Phased Adoption

Goal: Resolve dependencies locally (per method or short-lived scope) using
swift-dependencies, avoiding stored `@Dependency` properties on long-lived
`@Observable` types. Each phase ends with a review checkpoint before proceeding.

Status:
- Phase 1 complete: CLI/schema/pack diff fallbacks use localized resolution.
- Phase 2 complete: AppModel + SidebarModel migrated; stored `@Dependency` removed.
- Phase 3 complete: Core helpers use localized resolution; legacy shim removed.
- Phase 4 in progress: added storage-path defaults coverage.
- Phase 5 pending: optional local `@Dependency` style review.

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
let fileClient = DependencyValues.current.fileClient
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
let fileClient = DependencyValues.current.fileClient
```

PackDiffInputBuilder before:
```swift
let fileClient = fileClient ?? PackDiffEnvironment().fileClient
```

PackDiffInputBuilder after (localized resolution):
```swift
let fileClient = fileClient ?? DependencyValues.current.fileClient
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
- Replaced `FileClientProvider` usage in PersonaKitCore with localized
  `DependencyValues.current.fileClient`.
- Added `DependencyValues.current` shim in PersonaKitCore and removed
  `DependencyAccess.swift`.

Review checkpoint: confirm the pattern is consistent and still minimal.

### Phase 4: Tests and Regression Coverage
- Add targeted tests for any behavior that was previously implicit in stored
  dependencies.
- Ensure CLI and app parity remains intact.

In progress:
- Added storage-path defaults coverage for dependency-driven home directory
  resolution.

Review checkpoint: confirm tests cover the intended behaviors and no new
dependencies were introduced.

### Phase 5: Optional Local `@Dependency` Style Review
- Evaluate swapping `DependencyValues.current` uses to local `@Dependency`
  variables inside methods for consistency and readability.
- Decide on a single localized-resolution style and apply it uniformly.

Review checkpoint: agree on the preferred localized style before finalizing.
