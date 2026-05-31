# PersonaKit Grounding

Use this as a Cursor command or reusable prompt adapter.

Suggested project path:

```text
.cursor/commands/personakit-grounding.md
```

Suggested invocation:

```text
/personakit-grounding
```

Resolve the requested PersonaKit session before acting.

1. Identify the intended PersonaKit root and session id if the user supplied them.
2. Prefer PersonaKit MCP resources and tools when available.
3. If MCP tools are unavailable, use the installed `personakit` executable:
   - `personakit guidance`
   - `personakit list sessions`
   - `personakit recommend --goal "<task>"`
   - `personakit contract --session <id>`
   - `personakit contract --root <root> --session <id>`
   - `personakit export --session <id>`
   - `personakit validate`
4. Treat the resolved contract as authoritative for role, rules, allowed capabilities, forbidden actions, stop points, and provenance.
5. Continue only after the contract resolves cleanly.

Stop and ask when the root is ambiguous, the session cannot be resolved, or the
contract requires operator approval.

This command makes PersonaKit easier to invoke from the host. It does not
authorize a host tool, file edit, deployment, or handoff by itself.
