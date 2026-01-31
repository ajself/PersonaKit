PersonaKit MCP Server

The PersonaKit MCP server exposes PersonaKit data over stdio as read-only MCP Resources and Prompts.
It does not provide Tools.

What it provides
- Resources: read-only access to Personas, Kits, Tasks, Intent Templates, Skills, and Essentials.
- Prompts: session export and session graph.

Transport: stdio
The server runs as a local process and communicates over stdin/stdout. No ports are opened.

Required environment
- PERSONAKIT_ROOT: absolute path to the directory that contains Packs/.

Example launch (stdio)
From the repo root:
- npm run start

Example MCP client config
See `Docs/MCP/examples/stdio-npm.json` for a ready-to-use config.
If you want to run the built output directly, see `Docs/MCP/examples/stdio-node.json`.

Notes
- The MCP server is read-only and never writes to disk.
- The MCP server never executes commands or shells out to the Swift CLI.
- Output is deterministic (stable ordering, no timestamps).
