# Swift Style Guide

Use this runtime guide for active Swift implementation and review sessions.
Consult reference id `swift-style-guide-reference` when you need examples, tradeoff rationale, or deeper Swift structure guidance.

## Core Rules

1. Preserve the repo's declared Swift language mode and strict concurrency settings.
2. Do not weaken concurrency checking to make code compile.
3. `@unchecked Sendable` is prohibited unless the repository owner gave explicit approval for the exact change and the approval is recorded in `Docs/PersonaKit/Architecture/unchecked-sendable-approvals.txt`.
4. Treat `nonisolated(unsafe)` and `Task.detached` as last-resort exceptions that require a short exception comment.
5. Keep IO behind explicit clients or services and keep the dependency graph obvious.

## Readability

1. Use spaces, not tabs.
2. Wrap long calls and declarations vertically.
3. Keep opening braces on the same line.
4. Prefer clear naming:
   - `UpperCamelCase` for types
   - `lowerCamelCase` for functions and values
   - `is` / `has` / `can` / `should` for booleans
5. Prefer one primary type per file unless a tightly coupled helper is clearer in the same file.

## API And Testing

1. Prefer small, explicit APIs over broad abstractions.
2. Use typed, contextual errors where failure matters.
3. Prefer deterministic tests for non-trivial behavior.
4. Add regression tests for bug fixes when practical.

## Exceptions

If you must break a strong default, add a short exception comment that names the rule and tradeoff.
