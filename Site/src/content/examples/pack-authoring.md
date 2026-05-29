---
title: "Pack Authoring"
description: "A compact authoring contract for creating PersonaKit content with dry-runs, reuse, and validation."
kind: "contract"
routeSlug: "pack-authoring"
persona: "personakit-pack-author"
directive: "create-or-revise-pack-content"
kits:
  - "pack-authoring-guardrails"
authorizedSkills:
  - "personakit-create"
forbiddenSkills:
  - "product-scope-expansion"
  - "unbounded-pack-rewrite"
rootPath: "/examples/pack-authoring/personakit-root"
order: 4
---

This example shows PersonaKit being used to author PersonaKit content. `personakit create` is the mechanical authoring layer. The session is the reusable judgment layer.

The point is not to make PersonaKit an autonomous pack generator. The point is to keep repeated authoring work compact, scoped, dry-run first, and validated before it becomes durable project context.

## Mechanical Authoring, Reusable Judgment

`personakit create` can produce the file shape, but the session decides the lane: reuse existing entities where possible, avoid product-scope expansion, dry-run before writing, and validate before treating the result as project context.

This is also where reusable pieces get created or revised so future sessions can compose them instead of copying prompt paragraphs into a single oversized instruction.

## Runnable Commands

```bash
cd Site/public/examples/pack-authoring
personakit validate --root personakit-root
personakit contract --root personakit-root --session pack-authoring
demo_root="$(mktemp -d)"
cp -R personakit-root "$demo_root/.personakit"
personakit create persona --root "$demo_root/.personakit" --dry-run --id staff-code-quality-reviewer --name "Staff Code Quality Reviewer" --summary "Reviews code changes for behavior preservation, maintainability, and scoped risk."
```

## Expected Validation Shape

```text
Validation summary: personas=1 kits=1 directives=1 intents=0 references=0 skills=3 essentials=1 errors=0
```

## What To Inspect

- The session resolves to `personakit-pack-author` and `create-or-revise-pack-content`.
- `personakit-create` is authorized for mechanical authoring.
- `product-scope-expansion` and `unbounded-pack-rewrite` are forbidden.
- The directive requires dry-run before writing, then validation.
- The essential says to keep essentials compact unless long-form policy is explicitly requested.
- The create dry-run targets a temporary copy so the published sample root stays unchanged.
- The session keeps product-scope decisions out of a mechanical authoring pass.

## Practical Prompt

```text
Operate under pack-authoring. Create a Staff code-quality review session for this repo. Keep the generated PersonaKit content compact, use existing entities where possible, dry-run first, and validate afterward.
```

## Why This Belongs In PersonaKit

Manual JSON editing is fine for one-off pack changes. PersonaKit helps when the authoring pattern repeats and the project needs the same constraints each time: classify first, reuse existing entities, ask only high-impact shaping questions, dry-run before writing, validate after writing, and keep product-scope decisions out of the authoring pass.
