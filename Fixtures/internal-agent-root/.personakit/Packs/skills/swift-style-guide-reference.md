# Swift Style Guide

# Swift Style Guide — Repo-Agnostic (Swift 6.x)

A practical style guide for Swift codebases of any kind (apps, libraries, CLIs, services).
Optimized for:
- humans reading code quickly
- coding agents generating correct code on the first pass
- Swift 6 concurrency correctness

This is not a formatter spec. It is the intent layer that helps teams and agents make consistent choices.

## Terminology And Rule Levels

- MUST / MUST NOT: enforced rules
- SHOULD / SHOULD NOT: strong defaults; deviation requires a reason
- MAY: optional patterns

When in doubt, prefer clarity, safety, and explicitness over cleverness.

## Swift Language Mode And Build Settings

- The repo MUST specify and preserve its Swift language mode and strict concurrency settings.
- Code MUST NOT weaken concurrency checking to make code compile.
- Fix the model: ownership, isolation, and types.

### Concurrency Escape Hatches

The following are code smells and MUST NOT be used casually:
- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `Task.detached`

Repository policy override (PersonaKit): `@unchecked Sendable` is prohibited in all code and tests.

`nonisolated(unsafe)` and `Task.detached` MAY be used only as a last resort with a documented exception:

```swift
// EXCEPTION(SwiftStyle): Bridging legacy API that is externally synchronized.
// Default rule: Avoid concurrency escape hatches.
// Tradeoff: Compiler cannot verify thread safety; reviewed manually.
```

## Formatting And Layout

Prefer a formatter for exact whitespace. This guide focuses on structure and readability.

### Indentation And Line Length

- Use spaces, never tabs.
- Keep lines reasonably short. If a line becomes hard to scan, wrap it.
- Prefer vertical formatting for long argument lists.

Prefer:

```swift
let request = Request(
  userID: userID,
  includeMetadata: true,
  cachePolicy: .reloadIgnoringCache
)
```

Avoid:

```swift
let request = Request(userID: userID, includeMetadata: true, cachePolicy: .reloadIgnoringCache)
```

### Braces

- Opening braces stay on the same line.
- Always use braces for multi-line conditionals.

## Naming

### Types

- Types use `UpperCamelCase`.
- Prefer nouns for types: `ExportJob`, `HTTPClient`, `TokenStore`.

### Functions And Variables

- Functions and variables use `lowerCamelCase`.
- Functions should read like sentences: `loadProfile()`, `exportGIF()`, `parseArguments()`.

### Booleans

- Use `is`, `has`, `can`, or `should` prefixes.

### Protocols

- Prefer capability naming like `TokenProviding`, `Caching`, or `Clock`.

### Avoid Ambiguous Abbreviations

- Prefer `configuration` over `config` unless the abbreviation is universal in the repo.

## File And Folder Organization

- Group by domain or feature first, then by layer as needed.
- Avoid “misc” buckets. If you cannot name a folder, the boundary is unclear.

### One Primary Type Per File

- SHOULD keep one primary type per file.
- MAY include tightly coupled helpers in the same file if they are not reused elsewhere.

### File Naming

- File names SHOULD match the primary type.

## API Design

### Prefer Explicit, Small APIs

- Prefer task-focused methods over god objects.
- Prefer clear responsibilities over broad abstractions.

### Make Errors Meaningful

- Errors SHOULD be typed and actionable.
- Prefer `enum SomeError: Error` with cases that carry context.

### Avoid Boolean Traps

Prefer enums or options over multiple booleans:

```swift
enum CachePolicy {
  case useCache
  case reloadIgnoringCache
}

func load(cachePolicy: CachePolicy) async throws -> Data
```

## Dependencies And Boundaries

- IO MUST be behind explicit boundaries like clients or services and injected into callers.
- Code MUST NOT rely on global singletons as the primary access pattern.

You MAY use initializer injection, dependency containers, or explicit UI environments, but you MUST keep the dependency graph obvious.

## Swift Concurrency

### Actor Isolation

- UI-facing owner types SHOULD be `@MainActor`.
- Shared mutable state MUST be protected by actors or another safe isolation boundary.
- Avoid cross-actor mutation.

### Structured Concurrency

- Prefer `async/await` over callbacks.
- Prefer `Task {}` with clear ownership and lifetime over `Task.detached`.
- Consider cancellation for long-running work.

### Sendable Discipline

- Prefer making types safely `Sendable`.
- Do not paper over problems with `@unchecked Sendable`.

## Error Handling

- Errors SHOULD be propagated with context.
- Prefer `throws` for exceptional failure.
- Use `Result` only when it materially improves the API.

## Logging And Observability

- Logging SHOULD be structured and consistent.
- Avoid `print()` in production code.
- Prefer a single logging facade per repo.

## Testing

Tests are required for non-trivial behavior.

### What To Test

- Core logic and invariants
- Parsing and serialization
- Concurrency behavior and cancellation
- Error cases and edge cases

### Test Style

- Prefer deterministic tests: inject clocks, UUIDs, random sources, and schedulers where needed.
- Prefer small unit tests at boundaries over full-system tests by default.
- Bug fixes SHOULD include regression tests when practical.

If code is hard to test, treat that as a design signal to simplify boundaries or responsibilities.

## Documentation And Comments

- Prefer self-explanatory code and names.
- Comments SHOULD explain why, not what.

### Doc Comments

- Public APIs SHOULD have doc comments.
- Internal code MAY use doc comments when they clarify tricky behavior.

### Exceptions

When deviating from a MUST or SHOULD rule, add a short exception comment:

```swift
// EXCEPTION(SwiftStyle): <why this rule does not apply>.
// Default rule: <rule name>.
// Tradeoff: <what we accept>.
```

## Performance And Correctness

- Prefer correctness and clarity first.
- Measure before optimizing.
- When optimizing, localize complexity and document tradeoffs.

## Agent Guidance

When generating or editing Swift code:
- Follow MUST rules unless explicitly instructed otherwise.
- Do not introduce concurrency escape hatches to silence warnings.
- Keep APIs explicit and small.
- Add tests for non-trivial changes.

If the repo contains additional local rules, those override this guide.

Guiding principle: structure first, clarity second, cleverness last.
