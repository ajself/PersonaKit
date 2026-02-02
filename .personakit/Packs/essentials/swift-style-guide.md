# Swift Style Guide

# Swift Style Guide — Repo-Agnostic (Swift 6.x)

A practical style guide for Swift codebases of any kind (apps, libraries, CLIs, services).  
Optimized for:
- humans reading code quickly
- coding agents generating correct code on the first pass
- Swift 6 concurrency correctness

This is not a formatter spec. It is the *intent layer* that helps teams and agents make consistent choices.

---

## Terminology & Rule Levels

- **MUST / MUST NOT**: enforced rules
- **SHOULD / SHOULD NOT**: strong defaults; deviation requires a reason
- **MAY**: optional patterns

When in doubt: prefer clarity, safety, and explicitness over cleverness.

---

## Swift language mode & build settings (strict)

- The repo MUST specify and preserve its Swift language mode (e.g. Swift 6.2) and strict concurrency settings.
- Code MUST NOT weaken concurrency checking (or disable checks) to “make it compile”.
- Fix the model: ownership, isolation, and types.

### Concurrency escape hatches (code smells)
The following are considered **code smells** and MUST NOT be used casually:
- `@unchecked Sendable`
- `nonisolated(unsafe)`
- `Task.detached`

They MAY be used only as a last resort with a documented exception:

```swift
// EXCEPTION(SwiftStyle): Bridging legacy API that is externally synchronized.
// Default rule: Avoid @unchecked Sendable.
// Tradeoff: Compiler cannot verify thread safety; reviewed manually.
```

---

## Formatting & layout (hybrid)

> Prefer a formatter (swift-format) for exact whitespace. This guide focuses on structure and readability.

### Indentation & line length
- Use spaces (never tabs).
- Keep lines reasonably short. If a line becomes hard to scan, wrap it.
- Prefer vertical formatting for long argument lists.

**Prefer**
```swift
let request = Request(
  userID: userID,
  includeMetadata: true,
  cachePolicy: .reloadIgnoringCache
)
```

**Avoid**
```swift
let request = Request(userID: userID, includeMetadata: true, cachePolicy: .reloadIgnoringCache)
```

### Braces
- Opening brace goes on the same line.
- Always use braces for multi-line conditionals.

---

## Naming (strict)

### Types
- Types use `UpperCamelCase`.
- Prefer nouns for types: `ExportJob`, `HTTPClient`, `TokenStore`.

### Functions & variables
- Functions/vars use `lowerCamelCase`.
- Functions should read like sentences: `loadProfile()`, `exportGIF()`, `parseArguments()`.

### Booleans
- Use `is`, `has`, `can`, `should` prefixes:
  - `isEnabled`, `hasAccess`, `canRetry`, `shouldCache`

### Protocols
- Prefer capability naming:
  - `TokenProviding`, `Caching`, `Clock` (vs `TokenProviderProtocol`)
- If a protocol is primarily a role, naming like `URLSessioning` is acceptable but less preferred.

### Avoid ambiguous abbreviations
- Prefer `configuration` over `config` unless the abbreviation is universally understood in the repo.

---

## File & folder organization (hybrid)

- Group by domain/feature first, then by layer as needed.
- Avoid “misc” buckets. If you can’t name a folder, the boundary is unclear.

### One primary type per file (default)
- SHOULD keep one primary type per file.
- MAY include tightly-coupled helpers in the same file if they are not reused elsewhere.

### File naming
- File name SHOULD match the primary type: `ExportJob.swift`, `HTTPClient.swift`.

---

## API design (hybrid)

### Prefer explicit, small APIs
- Prefer task-focused methods over “god objects”.
- Prefer “do one thing well” types with clear responsibilities.

### Make errors meaningful
- Errors SHOULD be typed and actionable.
- Prefer `enum SomeError: Error` with cases that carry context.

```swift
enum ExportError: Error {
  case unsupportedFormat(String)
  case writeFailed(URL, underlying: Error)
}
```

### Avoid boolean traps
Prefer enums/options over multiple booleans:

**Prefer**
```swift
enum CachePolicy { case useCache, reloadIgnoringCache }
func load(cachePolicy: CachePolicy) async throws -> Data
```

**Avoid**
```swift
func load(useCache: Bool, forceReload: Bool) async throws -> Data
```

---

## Dependencies & boundaries (strict)

- IO MUST be behind explicit boundaries (clients/services) and injected into callers.
- Code MUST NOT rely on global singletons as the primary access pattern.

### Injection
You MAY use:
- initializer injection
- dependency container (e.g., swift-dependencies)
- explicit environment objects (UI contexts)

But you MUST keep the dependency graph obvious.

---

## Swift Concurrency (strict + pragmatic)

### Actor isolation
- UI-facing owner types SHOULD be `@MainActor`.
- Shared mutable state MUST be protected (actors or other safe isolation).
- Avoid cross-actor mutation.

### Structured concurrency
- Prefer `async/await` over callbacks.
- Prefer `Task {}` with clear ownership/lifetime over `Task.detached`.
- Cancellation MUST be considered for long-running work.

### Sendable discipline
- Prefer making types safely `Sendable` (value types, immutability).
- Avoid “papering over” with `@unchecked Sendable`.

---

## Error handling (hybrid)

- Errors SHOULD be propagated with context.
- Prefer `throws` for exceptional failure; avoid silently returning `nil` unless absence is expected.
- Use `Result` only when it materially improves the API (e.g., storing outcomes).

---

## Logging & observability (hybrid)

- Logging SHOULD be structured and consistent.
- Avoid `print()` in production code.
- Prefer a single logging facade per repo (e.g., OSLog wrapper) with categories.

---

## Testing (strict)

Tests are required for non-trivial behavior.

### What to test
- Core logic and invariants
- Parsing/serialization
- Concurrency behavior and cancellation
- Error cases and edge cases

### Test style
- Prefer deterministic tests: inject clocks, UUIDs, random, schedulers where applicable.
- Prefer small unit tests at boundaries over full-system tests by default.
- Bug fixes SHOULD include regression tests when practical.

If code is hard to test, treat that as a design signal to simplify boundaries or responsibilities.

---

## Documentation & comments (hybrid)

- Prefer self-explanatory code and names.
- Comments SHOULD explain *why*, not *what*.

### Doc comments
- Public APIs SHOULD have doc comments.
- Internal code MAY use doc comments when it clarifies tricky behavior.

### Exceptions
When deviating from a MUST/SHOULD rule, add a short exception comment:

```swift
// EXCEPTION(SwiftStyle): <why this rule doesn’t apply>.
// Default rule: <rule name>.
// Tradeoff: <what we accept>.
```

---

## Performance & correctness (hybrid)

- Prefer correctness and clarity first.
- Measure before optimizing.
- When optimizing, localize complexity and document tradeoffs.

---

## Agent guidance (for Codex / ChatGPT)

When generating or editing Swift code:
- Follow MUST rules without exception unless explicitly instructed.
- Do not introduce concurrency escape hatches to silence warnings.
- Keep APIs explicit and small.
- Add tests for non-trivial changes.

If the repo contains additional local rules (lint/format/config), those override this guide.

---
**Guiding principle:** Structure first. Clarity second. Cleverness last.
