---
name: personakit-grounding
description: Resolve PersonaKit or PK sessions before acting. Use when the user asks to operate under, resolve, inspect, recommend, trace, activate, export, or use a PersonaKit session or PK session; route through PersonaKit MCP or CLI contract resolution before reading raw .personakit or ~/.personakit files.
---

# PersonaKit Grounding

Use this as an OpenCode skill at:

```text
.opencode/skills/personakit-grounding/SKILL.md
```

OpenCode may also discover compatible skills from shared agent-skill paths in
some setups. Keep the skill content the same and let the host decide how it
surfaces the skill.

## Required Workflow

1. Identify the intended PersonaKit root and session id if the user supplied them.
2. Prefer PersonaKit MCP resources and tools:
   - Read `personakit://catalog/start` if the client or scope is unfamiliar.
   - Read session catalog resources when listing or selecting sessions.
   - Call `personakit_recommend_session` when no session id is supplied.
   - Call `personakit_resolve_contract` for the selected session.
   - Call `personakit_trace_session` when provenance, source files, or dependency reasons matter.
   - Call `personakit_export` only when a human-readable grounding payload is needed.
3. If MCP tools are unavailable, use the installed `personakit` executable for CLI fallback:
   - `personakit guidance`
   - `personakit list sessions`
   - `personakit recommend --goal "<task>"`
   - `personakit contract --session <id>`
   - `personakit contract --root <root> --session <id>` for repo-local session grounding
   - `personakit export --session <id>`
   - `personakit validate`
4. Treat the resolved contract as authoritative for persona, directive, kits, essentials, skill authorization, stop points, and provenance.
5. Continue the user's requested work only after the contract resolves cleanly.

## Boundary

- This host skill improves discovery and invocation.
- PersonaKit remains the source of contract authority.
- Available host skills are not automatically authorized by the resolved PersonaKit contract.
- Stop when the root is ambiguous, the session cannot be resolved, or the contract requires operator approval.
