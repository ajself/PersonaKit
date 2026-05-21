---
title: "CLI Maintenance"
description: "Bounded implementation with one authorized adapter and forbidden high-risk capabilities."
kind: "contract"
routeSlug: "cli-maintenance"
persona: "cli-maintainer"
directive: "bounded-cli-fix"
kits:
  - "cli-maintenance-guardrails"
authorizedSkills:
  - "opencode-cli"
forbiddenSkills:
  - "autonomous-agent-loop"
  - "deployment-runner"
rootPath: "/examples/swift-cli-maintenance/personakit-root"
order: 1
---

This example is the happy path for PersonaKit V1: one repeated coding work mode, one active persona, one directive, one authorized adapter capability, and explicit forbidden capabilities.

## Runnable Commands

```bash
cd Site/public/examples/swift-cli-maintenance
personakit validate --root personakit-root
personakit contract --root personakit-root --session cli-maintenance
personakit run --root personakit-root --session cli-maintenance --agent opencode --dry-run -- "Fix parser help text."
```

## Expected Validation Shape

```text
Validation summary: personas=1 kits=1 directives=1 intents=0 references=0 skills=3 essentials=1 errors=0
```

## What To Inspect

- The session resolves to `cli-maintainer` and `bounded-cli-fix`.
- `opencode-cli` is authorized for this session.
- `deployment-runner` and `autonomous-agent-loop` are forbidden.
- The dry-run payload includes the task only after the resolved context.

## Why This Is Better Than A Prompt Snippet

A prompt snippet can say "be careful." This contract says who the agent is acting as, what kind of work this is, which skill is authorized, which skills are forbidden, and when review is mandatory.
