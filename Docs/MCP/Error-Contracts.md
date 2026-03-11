# Error Contracts

This document defines stable MCP error shapes for common conversation workflows.

## Contract Shape

For recoverable invalid-params failures in conversation tools, PersonaKit uses two lines:

1. Primary failure message.
2. `Recovery: ...` guidance with a concrete next step.

Example:

```text
persona not found: missing-persona
Recovery: Read personakit://catalog/personas to list valid ids, then retry.
```

## Common Contracts

| Failure case | Primary message contract | Recovery contract |
| --- | --- | --- |
| Unknown tool | `Unknown tool name: <name>` | `Call list_tools and retry using one of the advertised tool names.` |
| Missing/invalid tool args | `Missing required argument: ...` or `Invalid argument type for ...` | Tool-specific argument hint line describing expected inputs |
| Missing entity id | `<entityType> not found: <id>` | `Read personakit://catalog/<type> to list valid ids, then retry.` |
| Missing sessions for recommendation | `No session files found in active scopes.` | `Create at least one Sessions/*.session.json file in the active PersonaKit scope.` |
| Invalid session id for trace/export/graph | Session loader failure message | `Read personakit://catalog/sessions to list valid ids, then retry with one session id.` |
| Invalid session ref for resolution | Session-reference failure message | `Use a valid session id from personakit://catalog/sessions or a path under Sessions/*.session.json in the active PersonaKit scope.` |
| validate called with args | `personakit_validate does not accept arguments.` | `Call personakit_validate with an empty argument object.` |

## Scope Startup Contracts

MCP startup errors remain explicit and deterministic:

- Missing scope: starts with `No PersonaKit scope found for MCP...`
- Invalid root: starts with `<source> root does not exist or is not a directory: ...`
- Missing `Packs/`: starts with `<source> root must contain Packs/: ...`
- Compatibility mode misuse: starts with `PERSONAKIT_ROOT_OVERRIDE requires PERSONAKIT_ROOT...`

See [Troubleshooting](./troubleshooting.md) for operator-facing fixes.
