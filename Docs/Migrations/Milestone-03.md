# Milestone 3 - CLI + SchemaValidate dependency alignment

Date: 2026-01-24
Status: complete

## Goals
- Align CLI and SchemaValidate with `FileClient` dependency usage.
- Remove direct `FileManager` usage in executable targets.
- Keep behavior/output identical.

## Changes
- Added swift-dependencies to `PersonaPadCLI` and `PersonaPadSchemaValidate` targets.
- CLI now uses `FileClient` for repo root discovery and user pack existence checks.
- Schema validator now uses `FileClient` for:
  - current directory resolution
  - repo root discovery
  - schema file reading
  - directory listing for JSON inputs

Files touched:
- Package.swift
- Sources/PersonaPadCLI/main.swift
- Sources/PersonaPadSchemaValidate/main.swift

## Tests
- swift test
- ./Scripts/release-check.sh

## Context for a new agent
- CLI/SchemaValidate should not call `FileManager` directly.
- `CLIEnvironment` and `SchemaEnvironment` are the entry points for dependency access.
- Inputs/outputs remain stable to preserve parity.

## Acceptance criteria
- CLI and validator outputs unchanged.
- `swift test` and `./Scripts/release-check.sh` pass.

## Relevant commit
- db09cbf refactor(cli): route filesystem access through dependencies
