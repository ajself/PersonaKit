# PersonaKit MCP (read-only)

This is a read-only MCP server that exposes PersonaKit packs as resources and prompts over stdio. It does not provide tools or execute any commands.

## Requirements
- Node.js 18+
- PERSONAKIT_ROOT env var pointing to a directory that contains `Packs/`
- `personakit` Swift CLI binary available (see "Personakit binary" below)

## Build

```sh
npm install
npm run build
```

## Run (stdio)

```sh
PERSONAKIT_ROOT=/path/to/PersonaKit npm run start
```

## Personakit binary

The MCP adapter invokes the Swift `personakit` binary for prompt output.

Resolution order:
1. `PERSONAKIT_BIN` environment variable (must point to a `personakit` executable)
2. `../.build/debug/personakit` relative to `personakit-mcp/`
3. `../.build/release/personakit` relative to `personakit-mcp/`

Build the binary from the repo root:

```sh
swift build
```

## Verify
Use an MCP inspector/client to call:
- resources/list
- resources/read (example):
  - personakit://essentials/swiftui-style-guide
- prompts/list
- prompts/get (example):
  - id: personakit.session.export
  - arguments:
    - personaId: senior-swiftui-engineer
    - taskId: apply-style

Notes:
- This server never writes to disk.
- Resources and prompts are deterministic (sorted, stable output).
- Features: Resources + Prompts only (no Tools yet).
