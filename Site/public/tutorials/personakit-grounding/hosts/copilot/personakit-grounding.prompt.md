# PersonaKit Grounding

Resolve the requested PersonaKit session before acting.

## Use When

Use this prompt when a person asks you to operate under, resolve, inspect,
recommend, trace, activate, export, or use a PersonaKit session or PK session.

## Workflow

1. Identify the intended PersonaKit root and session id if supplied.
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

## Boundary

This prompt is a host front door. PersonaKit remains the authority for the
operating contract.

Do not read raw `.personakit` or `~/.personakit` files first unless the user is
authoring PersonaKit content, resolution fails and file-level diagnostics are
needed, or the resolved contract directs you to inspect those files.

Stop and ask when the root is ambiguous, the session cannot be resolved, or the
contract requires operator approval.
