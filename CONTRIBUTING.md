# Contributing

Status: Active
Owner: Maintainers
Last Reviewed: 2026-05-12

## Why This Exists

PersonaKit is intentionally narrow for V1. Contributions should make the CLI-first operating-contract workflow clearer, safer, or easier to trust.

## What To Work On

Good V1 contributions usually improve:

- deterministic contract resolution
- `personakit run` dry-run and launcher behavior
- validation, error messages, and help text
- public examples and onboarding docs
- tests that protect ordering, scope resolution, and safety boundaries

Avoid contributions that add:

- multiple agent adapters without maintainer approval
- workflow orchestration or autonomous planning
- persistence, memory, or session continuation
- Studio expansion as a V1 requirement
- broad refactors unrelated to the issue or change

## Development Setup

Build the CLI:

```bash
swift build --product personakit
```

Run the test suite:

```bash
swift test
```

Validate the fixture pack:

```bash
swift run personakit validate --root Fixtures/kit-root
```

Validate the public starter:

```bash
swift run personakit validate --root Examples/public-starter/.personakit
```

Check the V1 dry-run path:

```bash
swift run personakit run --root Examples/public-starter/.personakit --session solo-dev-v1 --agent opencode --dry-run -- "Verify public V1 onboarding."
```

## Pull Request Expectations

- Keep diffs small and reviewable.
- Update docs in the same change when behavior changes.
- Add or update tests for behavioral changes.
- Preserve deterministic output ordering.
- Use Conventional Commits for commit messages when possible.

## Related Docs

- [README](./README.md)
- [V1 Direction](./Docs/V1_DIRECTION.md)
- [MCP Guide](./Docs/mcp.md)
- [Agent Rules](./AGENTS.md)
