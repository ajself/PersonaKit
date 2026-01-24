# Milestone 2 - Core IO via FileClient

Date: 2026-01-24
Status: complete

## Goals
- Eliminate direct `FileManager` usage in PersonaPadCore.
- Route all filesystem access through `FileClient` (swift-dependencies).
- Preserve determinism and v1 composition semantics.

## Changes
- Added `FileClientProvider` to centralize `@Dependency(\.fileClient)` access.
- Updated core components to accept `FileClient` or pull from dependencies:
  - `PersonaLoader` reads via `fileClient.readData`.
  - `PersonaPackImportPlan` uses `fileClient` for file discovery and reads.
  - `PersonaPackLocator` uses `fileClient.fileExists` + `contentsOfDirectory`.
  - `PinnedPersonasStore` and `SavedFiltersStore` use `fileClient` for IO.
  - `PersonaPadStoragePaths.standard` uses dependency-provided home dir.
  - `UserPackLoader` reads directories and checks `isDirectory` via `fileClient`.
  - `PersonaDescriptor` uses `fileClient.homeDirectory()` to abbreviate paths.

Files touched:
- Sources/PersonaPadCore/Dependencies/DependencyAccess.swift
- Sources/PersonaPadCore/Describe.swift
- Sources/PersonaPadCore/Loader.swift
- Sources/PersonaPadCore/PackImport.swift
- Sources/PersonaPadCore/PackLocator.swift
- Sources/PersonaPadCore/PinnedPersonasStore.swift
- Sources/PersonaPadCore/SavedFilters.swift
- Sources/PersonaPadCore/Storage.swift
- Sources/PersonaPadCore/UserPackLoader.swift

## Tests
- swift test
- ./Scripts/release-check.sh

## Context for a new agent
- Core IO should never call `FileManager` directly.
- Use `FileClient` for read/write/list/enumerator/isDirectory/homeDirectory.
- Storage paths remain deterministic; the dependency just supplies home dir.
- Core composition semantics remain unchanged (see v1 contract).

## Acceptance criteria
- No direct `FileManager` in core paths.
- Deterministic outputs unchanged.
- `swift test` and `./Scripts/release-check.sh` pass.

## Relevant commit
- 3e32530 refactor(core): route IO through FileClient
