# PersonaKit MCP Guide

Status: Active
Owner: AJ
Last Reviewed: 2026-04-25

## Why This Exists

PersonaKit MCP gives AI tools a read-only way to discover and resolve PersonaKit operating contracts.

It is for grounding, inspection, and provenance. It is not an execution lane. For V1 execution, use `personakit run`.

## What To Do

Start the server:

```bash
personakit mcp
```

An unfamiliar MCP client or AI agent should follow this path:

1. Read `personakit://catalog/start`.
2. Read `personakit://catalog/sessions` or call `personakit_recommend_session`.
3. Call `personakit_resolve_contract` for the selected session.
4. Call `personakit_trace_session` when provenance matters.
5. Read raw pack or essential resources only as needed.

The key tools are:

- `personakit_recommend_session`: find a session for a natural-language task.
- `personakit_resolve_contract`: resolve persona, directive, kits, essentials, and skill authorization.
- `personakit_trace_session`: audit where resolved constraints came from.
- `personakit_resolve_references`: select triggered references for explicit paths or tags.
- `personakit_export`: assemble human-readable Markdown grounding.

## Safety Model

PersonaKit MCP is read-only.

MCP resources and tools provide context. They do not authorize execution, file mutation, shell commands, workflow orchestration, memory, or autonomous planning.

If a contract does not authorize a needed skill, stop and re-ground instead of improvising.

## How To Verify

Use these checks after MCP behavior changes:

```bash
swift test --filter MCP
swift run personakit validate
swift run personakit mcp --help
```

## Related Docs

- [Repository Overview](../README.md)
- [V1 Direction](./V1_DIRECTION.md)
