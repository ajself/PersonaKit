---
title: "Review Session"
description: "A read-only review contract that produces findings without becoming the implementer."
chooserTitle: "Read-Only Review"
chooserDescription: "Use Review Session when the reviewer should produce findings without becoming the implementer."
kind: "contract"
routeSlug: "review-session"
persona: "behavior-reviewer"
directive: "behavior-preserving-review"
kits:
  - "review-guardrails"
authorizedSkills:
  - "read-only-review"
forbiddenSkills:
  - "code-editing"
  - "deployment-runner"
rootPath: "/examples/review-session/personakit-root"
order: 3
sourceFiles:
  - label: "Session"
    path: "Sessions/behavior-review.session.json"
  - label: "Persona"
    path: "Packs/personas/behavior-reviewer.persona.json"
  - label: "Directive"
    path: "Packs/directives/behavior-preserving-review.directive.json"
  - label: "Kit"
    path: "Packs/kits/review-guardrails.kit.json"
  - label: "Authorized Skill"
    path: "Packs/skills/read-only-review.skill.json"
  - label: "Forbidden Skill"
    path: "Packs/skills/code-editing.skill.json"
---

This example is intentionally non-executing. It shows how PersonaKit can define a review identity without authorizing code editing, deployment, or tool-driven follow-up work.

Use this when the important boundary is separation of authority: the reviewer can identify defects, but cannot quietly become the fixer.

## Authority Split

The reviewer reports confirmed defects, risks, and missing validation. If a fix is needed, implementation waits for explicit approval and a separate work mode.

## Key Contract Signal

```text
forbiddenSkillIds: code-editing, deployment-runner
```

## Runnable Commands

```bash
cd Site/public/examples/review-session
personakit validate --root personakit-root
personakit contract --root personakit-root --session behavior-review
personakit export --root personakit-root --session behavior-review
```

## Expected Validation Shape

```text
Validation summary: personas=1 kits=1 directives=1 intents=0 references=0 skills=3 essentials=1 errors=0
```

## What To Inspect

- The session resolves to `behavior-reviewer` and `behavior-preserving-review`.
- `read-only-review` is authorized.
- `code-editing` and `deployment-runner` are forbidden.
- The directive requires stopping if implementation is needed.
- The export path produces human-readable grounding without launching an agent.

## Why This Matters

Without a separate review session, an assistant may blend reviewer and implementer behavior. PersonaKit makes review identity explicit and keeps execution authority separate.
