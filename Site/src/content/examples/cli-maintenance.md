---
title: "CLI Maintenance"
description: "The happy path for bounded implementation with one authorized adapter and clear stop points."
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

This example is the happy path for a bounded PersonaKit implementation lane. It shows how one adapter capability can be authorized while deployment and autonomous loops are forbidden.

Use this when a practical coding task repeats often enough that the same role, stop points, and verification should be visible every time.

## Prompt This Replaces

```text
Fix this small CLI bug. Be careful, do not deploy anything, do not start a long-running agent loop, and show me what would happen before you run it.
```

PersonaKit keeps that repeated caution out of the task prompt and puts it in the session contract where it can be inspected.

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
- The directive stops before new adapters, arbitrary command execution, persistence, or orchestration.

## Why This Is Better Than A Prompt Snippet

A prompt snippet can say "be careful." This contract says who the agent is acting as, what kind of work this is, which skill is authorized, which skills are forbidden, and when review is mandatory.

The prompt can stay small because the durable boundary now lives in PersonaKit.
