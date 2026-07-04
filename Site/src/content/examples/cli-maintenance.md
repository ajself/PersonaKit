---
title: "CLI Maintenance"
description: "The happy path for bounded implementation with one authorized capability and clear stop points."
chooserTitle: "Bounded Implementation"
chooserDescription: "Use CLI Maintenance when code editing is allowed and deployment or autonomous loops must stay forbidden."
kind: "contract"
routeSlug: "cli-maintenance"
persona: "cli-maintainer"
directive: "bounded-cli-fix"
kits:
  - "cli-maintenance-guardrails"
authorizedSkills:
  - "code-editing"
forbiddenSkills:
  - "autonomous-agent-loop"
  - "deployment-runner"
rootPath: "/examples/swift-cli-maintenance/personakit-root"
order: 1
sourceFiles:
  - label: "Session"
    path: "Sessions/cli-maintenance.session.json"
  - label: "Persona"
    path: "Packs/personas/cli-maintainer.persona.json"
  - label: "Directive"
    path: "Packs/directives/bounded-cli-fix.directive.json"
  - label: "Kit"
    path: "Packs/kits/cli-maintenance-guardrails.kit.json"
  - label: "Authorized Skill"
    path: "Packs/skills/code-editing.skill.json"
  - label: "Forbidden Skill"
    path: "Packs/skills/deployment-runner.skill.json"
---

This example is the happy path for a bounded PersonaKit implementation lane. It shows how code editing can be authorized while deployment and autonomous loops are forbidden.

Use this when a practical coding task repeats often enough that the same role, stop points, and verification should be visible every time.

## Prompt This Replaces

```text
Fix this small CLI bug. Be careful, do not deploy anything, do not start a long-running agent loop, and show me what would happen before you run it.
```

PersonaKit keeps that repeated caution out of the task prompt and puts it in the session contract where it can be inspected.

## Key Contract Signal

```text
authorizedSkillIds: code-editing
```

## Runnable Commands

```bash
cd Site/public/examples/swift-cli-maintenance
personakit validate --root personakit-root
personakit contract --root personakit-root --session cli-maintenance
personakit export --root personakit-root --session cli-maintenance
```

Add `--stats` to the export command to print a size summary (lines, bytes, sections) to stderr before handoff.

## Expected Validation Shape

```text
Validation summary: personas=1 kits=1 directives=1 skills=4 errors=0
```

## What To Inspect

- The session resolves to `cli-maintainer` and `bounded-cli-fix`.
- `code-editing` is authorized for this session.
- `deployment-runner` and `autonomous-agent-loop` are forbidden.
- The export output is inspectable before any coding tool starts work.
- The directive stops before arbitrary command execution, persistence, or orchestration.

## Why This Is Better Than A Prompt Snippet

A prompt snippet can say "be careful." This contract says who the agent is acting as, what kind of work this is, which capability is authorized, which skills are forbidden, and when review is mandatory.

The prompt can stay small because the durable boundary now lives in PersonaKit.
