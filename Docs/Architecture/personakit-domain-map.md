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

## Discussion Primitives (Planned in M2)

1. Explain entity
- Input: `type + id`
- Output: core fields + dependency edges + resolution source.

2. Compare entities
- Input: two entity refs
- Output: overlap, differences, and conflict notes.

3. Recommend session
- Input: goal + constraints
- Output: ranked session/persona/directive combinations with rationale.

4. Trace session
- Input: `sessionId`
- Output: persona -> kits -> essentials + directive requirements.

## Non-goals

1. MCP write/edit operations for pack entities.
2. Hidden or implicit resolution outside declared scope precedence.
3. Narrative-only explanations that cannot be traced to concrete ids.
