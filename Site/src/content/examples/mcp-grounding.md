---
title: "MCP Grounding"
description: "Read-only contract resolution before an agent chooses host-local tools."
kind: "contract"
routeSlug: "mcp-grounding"
persona: "mcp-grounded-agent"
directive: "resolve-before-tools"
kits:
  - "mcp-grounding-guardrails"
authorizedSkills:
  - "read-only-mcp-grounding"
forbiddenSkills:
  - "autonomous-agent-loop"
  - "mcp-writeback"
rootPath: "/examples/mcp-consumer-agent/personakit-root"
order: 2
---

This example shows how PersonaKit fits when an agent can access the PersonaKit MCP server.

The important boundary: MCP is read-only grounding. It does not authorize file mutation, command execution, agent launch, or workflow orchestration.

## Runnable Commands

```bash
cd Site/public/examples/mcp-consumer-agent
personakit validate --root personakit-root
personakit contract --root personakit-root --session mcp-grounding
```

## Expected Validation Shape

```text
Validation summary: personas=1 kits=1 directives=1 intents=0 references=0 skills=3 essentials=1 errors=0
```

## What To Inspect

- The session resolves to `mcp-grounded-agent` and `resolve-before-tools`.
- `read-only-mcp-grounding` is authorized.
- `mcp-writeback` and `autonomous-agent-loop` are forbidden.
- The directive requires grounding before host-local tool selection.

## Agent Behavior This Should Produce

An MCP-aware agent should ground itself with PersonaKit before selecting host-local skills, treat MCP resources and tools as read-only context, trace the session when provenance matters, and stop when a needed capability is undeclared or unauthorized.
