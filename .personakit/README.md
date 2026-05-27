# PersonaKit Authored Source

This directory contains PersonaKit authored source.

Do not use these files as normal agent operating context. For agent startup, resolve a session through PersonaKit MCP or CLI:

- MCP: read `personakit://catalog/start`, then resolve the intended session.
- CLI: run `personakit guidance`, then `personakit contract --root .personakit --session <id>` or `personakit export --root .personakit --session <id>`.

Read raw files here only for PersonaKit authoring, validation failures, or resolver diagnostics.
