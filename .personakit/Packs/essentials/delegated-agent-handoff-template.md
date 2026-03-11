# Delegated Agent Handoff Template

Use this template when a planning pass expects a role to be staffed by a
spawned agent and the lane needs a compact, reusable handoff packet.

## Purpose

1. Keep delegated handoffs explicit, bounded, and reusable.
2. Make PersonaKit grounding requirements visible before execution begins.
3. Standardize the fallback shape when live PersonaKit MCP is unavailable.

## When To Use

Use one handoff packet per delegated role when:

1. A spawned agent is expected to execute or review a bounded work item.
2. The lane depends on PersonaKit context for persona, directive, kits, or
   essentials.
3. The parent lane needs to preserve a durable fallback artifact for bounded
   implementation or review work.

Do not use a static export handoff as a silent substitute for:

1. planning
2. hiring
3. remediation
4. open-ended context discovery

Those lanes should use live PersonaKit MCP or stop as `grounding-blocked`.

## Grounding Policy

1. Preferred path:
   - live PersonaKit MCP
2. Approved fallback:
   - static PersonaKit export for bounded implementation or review work
3. Failure disposition:
   - `grounding-blocked`

## Required Fields

Each handoff packet should include:

1. Role name.
2. Authoritative operating persona ID.
3. Required session ID or directive ID.
4. Grounding mode:
   - `live-mcp`
   - `static-export`
5. Static export path when `groundingMode = static-export`.
6. PersonaKit source IDs:
   - persona
   - directive
   - kits
   - essentials
7. Objective summary.
8. Scope boundary.
9. Write scope.
10. Acceptance criteria.
11. Validation commands or evidence expectations.
12. Stop points and return conditions.
13. Failure disposition.
14. Artifact references.
15. Grounding source path or export source reference.
16. Snapshot date when `groundingMode = static-export`.
17. Snapshot revision marker when one exists.
18. Optional review personas kept separate from execution identity.

## Static Export Guardrails

When `groundingMode = static-export`:

1. Mark the export as frozen.
2. Include the source session/persona/directive IDs.
3. Include the resolved kits and essentials.
4. Include scope boundary and validation expectations.
5. Include the grounding source path and snapshot date.
6. State that the delegated lane must not improvise beyond the snapshot.

## Markdown Template

```md
## Delegated Agent Handoff Packet

- Role:
- Operating persona ID:
- Review personas:
- Required session ID:
- Required directive ID:
- Grounding mode: `live-mcp` | `static-export`
- Static export path:
- Grounding source path:
- Failure disposition: `grounding-blocked`

### Objective

- Summary:
- Scope boundary:
- Write scope:

### PersonaKit Context

- Persona ID:
- Operating persona confirmation:
- Directive ID:
- Kit IDs:
- Essential IDs:
- Artifact references:

### Acceptance

- Acceptance criteria:
- Validation commands or evidence:
- Stop points:
- Return conditions:

### Static Export Notes

- Export status: `frozen`
- Snapshot date:
- Snapshot revision marker:
- Snapshot limitations:
- Do-not-improvise note:
- Execution identity note:
```
