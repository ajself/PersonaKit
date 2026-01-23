# PersonaPad v1.0.0

PersonaPad is a **local, deterministic macOS utility for persona-based prompt composition**.

v1.0.0 is the “boring reliability” release:
- consistent output
- predictable structure
- clear failures
- no execution, no accounts, no tracking

## What this release guarantees

- **Deterministic composition**: same persona + same inputs → identical output.
- **Schema v1 stability**: personas validate against Schema v1.
- **App + CLI parity**: the macOS app and `personapad` compose prompts using the same core logic.
- **Local-first**: no network access, no analytics, no provider integration.

## Explicit non-goals

PersonaPad v1.0.0 is not:
- a chat client or runtime
- an AI provider integration
- cloud sync / accounts
- a prompt optimizer
- a persona inheritance/composition system
- a plugin platform

## Notes for persona authors

- `extends` / `systemAppend` are **not supported** in v1.
- If present, they are treated as **invalid** and produce a loud validation error.

## How to verify

From repo root, run:
```bash
./Scripts/release-check.sh
```

This runs tests, schema validation for Examples, and CLI smoke checks.
