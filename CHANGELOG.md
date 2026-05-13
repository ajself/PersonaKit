# Changelog

All notable changes to PersonaKit will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and PersonaKit uses semantic versioning once public releases begin.

## Unreleased

### Changed

- Set the public prerelease toolchain version to `0.3.0`.
- Made `personakit init` refuse non-empty destinations unless `--force` is provided.
- Replaced the root `.personakit` context with the public V1 starter; moved internal agent context to fixtures.

### Added

- MIT license and public contribution/security documentation.
- CLI-first public onboarding path for V1.
- Public starter example showing a minimal PersonaKit root and dry-run flow.
- GitHub Actions CI for Swift tests, fixture validation, and V1 dry-run checks.
- Adapter authorization checks for `personakit run`.
- Fake adapter launch coverage for argv, runtime payload files, exit codes, and missing executable handling.
- Repeatable Studio review fixtures and screenshot capture target.

### Confirmed

- V1 remains focused on deterministic session contract resolution and `personakit run`.
- `opencode` remains the only supported V1 agent adapter unless maintainers explicitly approve another adapter.
- Studio is available in the repository but is not part of the V1 release bar.
