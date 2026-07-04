---
title: "MCP Grounding"
description: "How MCP-aware agents should resolve PersonaKit context before choosing host-local tools."
chooserTitle: "MCP Grounding"
chooserDescription: "Use MCP Grounding when a client should resolve PersonaKit context before choosing host-local tools."
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
sourceFiles:
  - label: "Session"
    path: "Sessions/mcp-grounding.session.json"
  - label: "Persona"
    path: "Packs/personas/mcp-grounded-agent.persona.json"
  - label: "Directive"
    path: "Packs/directives/resolve-before-tools.directive.json"
  - label: "Kit"
    path: "Packs/kits/mcp-grounding-guardrails.kit.json"
  - label: "Authorized Skill"
    path: "Packs/skills/read-only-mcp-grounding.skill.json"
  - label: "Forbidden Skill"
    path: "Packs/skills/mcp-writeback.skill.json"
---

This example shows how PersonaKit fits when an agent can access the PersonaKit MCP server. The agent should ground itself first, then choose tools only if the resolved contract allows them.

The important boundary: MCP is read-only grounding. It does not authorize file mutation, command execution, agent launch, or workflow orchestration.

## Unsafe Interpretation This Prevents

An MCP-aware agent might otherwise treat "PersonaKit context is available" as permission to choose tools, mutate files, or launch a worker. This contract says the opposite: resolve context first, then stop unless the needed capability is explicitly authorized.

## Key Contract Signal

```text
authorizedSkillIds: read-only-mcp-grounding
```

## Runnable Commands

```bash
cd Site/public/examples/mcp-consumer-agent
personakit validate --root personakit-root
personakit contract --root personakit-root --session mcp-grounding
personakit refs --root personakit-root read-only-mcp-grounding
```

`personakit refs` makes the provenance concrete: it shows the persona and directive that reach for `read-only-mcp-grounding`, so you can confirm the grounding skill is wired into the session before trusting it.

## Expected Validation Shape

```text
Validation summary: personas=1 kits=1 directives=1 skills=4 errors=0
```

## What To Inspect

- The session resolves to `mcp-grounded-agent` and `resolve-before-tools`.
- `read-only-mcp-grounding` is authorized.
- `mcp-writeback` and `autonomous-agent-loop` are forbidden.
- The directive requires grounding before host-local tool selection.
- MCP remains a context and provenance surface, not an execution path.

## Agent Behavior This Should Produce

An MCP-aware agent should ground itself with PersonaKit before selecting host-local skills, treat MCP resources and tools as read-only context, trace the session when provenance matters, and stop when a needed capability is undeclared or unauthorized.
