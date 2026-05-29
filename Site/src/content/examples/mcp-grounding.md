---
title: "MCP Grounding"
description: "How MCP-aware agents should resolve PersonaKit context before choosing host-local tools."
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

This example shows how PersonaKit fits when an agent can access the PersonaKit MCP server. The agent should ground itself first, then choose tools only if the resolved contract allows them.

The important boundary: MCP is read-only grounding. It does not authorize file mutation, command execution, agent launch, or workflow orchestration.

## Unsafe Interpretation This Prevents

An MCP-aware agent might otherwise treat "PersonaKit context is available" as permission to choose tools, mutate files, or launch a worker. This contract says the opposite: resolve context first, then stop unless the needed capability is explicitly authorized.

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
- MCP remains a context and provenance surface, not an execution path.

## Agent Behavior This Should Produce

An MCP-aware agent should ground itself with PersonaKit before selecting host-local skills, treat MCP resources and tools as read-only context, trace the session when provenance matters, and stop when a needed capability is undeclared or unauthorized.
