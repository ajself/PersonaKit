# PersonaKit Domain Map

Last Updated: 2026-03-07
Status: Draft (M1)

## Purpose

Define a canonical, implementation-aligned model for PersonaKit entities and their relationships so CLI, MCP, and Studio can present consistent explanations and discovery flows.

## Canonical Entities

1. `persona`
- File: `Packs/personas/<id>.persona.json`
- Core fields: `id`, `name`, `summary`, `responsibilities`, `values`, `nonGoals`, `defaultKitIds`, `allowedSkillIds`, `forbiddenSkillIds`

2. `directive`
- File: `Packs/directives/<id>.directive.json`
- Core fields: `id`, `title`, `goal`, `steps`, `acceptanceCriteria`, `verification`, `requiresIntentTemplateIds`, `requiresSkillIds`

3. `kit`
- File: `Packs/kits/<id>.kit.json`
- Core fields: `id`, `name`, `summary`, `essentialIds`

4. `session`
- File: `Sessions/<id>.session.json`
- Core fields: `id`, `personaId`, `directiveId`, optional `kitOverrides`

5. `intent template`
- File: `Packs/intents/<id>.intent.json`
- Core fields: `id`, `name`, `description`, `parameters`, `risk`, `requiredSkillIds`, `includedEssentialIds`

6. `skill`
- File: `Packs/skills/<id>.skill.json`
- Core fields: `id`, `name`, `description`, `providedBy`, `risk`, `notes`

7. `essential`
- File: `Packs/essentials/<id>.md`
- Purpose: reusable grounding content for kits and intent templates.

## Relationship Model

1. Session composition
- A `session` selects exactly one `persona` and one `directive` by id.
- A `session` may provide `kitOverrides`.

2. Persona defaults
- A `persona` declares `defaultKitIds`.
- Session resolution uses persona defaults unless overridden.

3. Kit expansion
- A `kit` expands to `essentialIds`.

3a. Runtime contract injection
- Resolved-session surfaces also inject required system essentials that are not
  declared by kits.
- In this repository, `persona-activation-contract` is a built-in required
  runtime essential.
- A project-local `Packs/essentials/persona-activation-contract.md` file may
  override the built-in default for the active root.
- This injection applies only to resolved-session outputs and traces, not to raw
  kit metadata or catalog/entity reads.

4. Directive dependencies
- A `directive` may require intent templates and skills.

5. Intent template dependencies
- An `intent template` may require skills and include essentials.

## Scope and Resolution Semantics

1. Registry load order (`scopes.loadOrder`)
- Earlier roots load first.
- Later roots override by id.

2. File resolution order (`scopes.resolutionOrder`)
- First matching file wins.
- Used for session/essential reads and resource URI lookup.

3. MCP scope mode
- MCP runs single-scope selection (project or global) for deterministic behavior.

## MCP Catalog Surfaces (M1)

New catalog resources are exposed as virtual MCP resources:

1. `personakit://catalog/index`
2. `personakit://catalog/personas`
3. `personakit://catalog/kits`
4. `personakit://catalog/directives`
5. `personakit://catalog/intents`
6. `personakit://catalog/skills`
7. `personakit://catalog/essentials`
8. `personakit://catalog/sessions`
9. `personakit://catalog/api`

All catalog payloads are deterministic JSON (`schemaVersion: 1`) and include stable ordering.

## Discussion Primitives (Implemented in M2 Initial Slice)

1. Explain entity (`personakit_explain_entity`)
- Input: `entityType + id`
- Output: key fields, relationship edges, and deterministic metadata per entity kind.

2. Compare entities (`personakit_compare_entities`)
- Input: `entityType + leftId + rightId`
- Output: scalar/list matches and deterministic differences.

3. Recommend session (`personakit_recommend_session`)
- Input: `goal` (+ optional `limit`)
- Output: ranked session/persona/directive combinations with deterministic scoring policy.

4. Resolve session ref (`personakit_resolve_session_ref`)
- Input: `sessionRef`
- Output: canonical session id plus resolved session metadata for id-or-path callers.

5. Trace session (`personakit_trace_session`)
- Input: `sessionId`
- Output: session resolution graph (persona/directive/kits/intents/skills/essentials) with explicit edge sets.

## Non-goals

1. MCP write/edit operations for pack entities.
2. Hidden or implicit resolution outside declared scope precedence.
3. Narrative-only explanations that cannot be traced to concrete ids.
