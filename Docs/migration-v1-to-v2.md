# Migrating Packs From PersonaKit 1 To PersonaKit 2

This guide is for an AI coding agent asked to migrate an existing `.personakit` root from PersonaKit 1.x to 2.0. It
covers what changed, how to rewrite each authored entity, which CLI commands moved, and how to verify the result.

PersonaKit 2 is a **breaking pack-format change**. Three entity types were removed and their content folded into the
entities that survived. There is no automatic migration command; `version` fields are reviewable metadata and PersonaKit
never migrates on them. You rewrite the pack files, then validate. The engine's job (deterministic resolution,
inspection, export, read-only grounding) is unchanged; only the authored shape moved.

## What Changed At A Glance

The entity model collapsed from eight authored types to five.

| PersonaKit 1 entity | PersonaKit 2 | What to do |
| --- | --- | --- |
| **Reference** (`Packs/references/`, `*.reference.json` + `.md`) | Removed. Folded into **Skill**. | Rewrite as a grounding skill in `Packs/skills/`. |
| **Essential** (`Packs/essentials/`, bare `*.md`) | Removed. Folded into **grounding Skills** and **Persona** fields. | Move standing grounding into an always-on grounding skill; move identity/framing text into persona fields. |
| **Intent Template** (`Packs/intents/`) | Removed. Folded into **Directive**. | Move `parameters`, `risk`, and required skills onto the directive that used it. |
| **Persona** | Kept. Gained `environment`. | Optionally add the `environment` array. |
| **Directive** | Kept. Lost `requiresIntentTemplateIds` and `referenceIds`. | Delete those fields; absorb intent-template content. |
| **Kit** | Kept, but narrowed. Lost `essentialIds`, `referenceIds`, `intentTemplateIds`. | Fold everything a kit bundled into `skillIds`. |
| **Skill** | Kept. Gained `triggerRules` and a companion `.md` grounding body. Most fields now optional. | Existing skills keep working; references become new grounding skills. |
| **Session** | Kept, unchanged. | No change. |

New in 2.0, derived from the resolved contract (not authored): a **checks manifest** (`personakit checks`), a
`# Boundaries` section in the export, and optional **Claude Code PreToolUse enforcement** (`personakit enforce`,
`personakit hook-check`). These are outputs, not new files you author.

## Schema-Level Diff

Removed schemas: `reference.schema.json`, `essential.schema.json`, `intentTemplate.schema.json`.
Added schema: `checks.schema.json` (a derived artifact, not a hand-authored entity).

Field changes on surviving entities:

- **Persona**: added optional `environment: [String]`. (`forbiddenCapabilities` already existed in 1.1.)
- **Directive**: removed `requiresIntentTemplateIds` and `referenceIds`; kept `requiresSkillIds`; `parameters` and
  `risk` now carry what intent templates used to hold.
- **Skill**: added `triggerRules`; relaxed required fields to just `id`, `version`, `name`, `description`
  (`providedBy`, `risk`, `notes` are now optional). A skill with `triggerRules` plus a companion `.md` is a **grounding
  skill**.
- **Kit**: removed `essentialIds`, `referenceIds`, and `intentTemplateIds`; only `skillIds` remains. `essentialIds` is
  no longer required, so a kit can be as small as its identity plus a `skillIds` list.

## Migration Steps

Work one entity type at a time and validate after each. Author with `personakit create <entity>` rather than
hand-editing where you can; it emits the canonical JSON shape (alphabetized keys, two-space indent, spaces around
colons) so your diffs stay clean.

### 1. References → Grounding Skills

A v1 reference was trigger-gated grounding: a `*.reference.json` (`id`, `version`, `name`, `summary`, `triggerRules`)
usually beside a companion `.md` body. In v2 that is exactly a grounding skill.

For each reference:

1. Move the companion `.md` from `Packs/references/` to `Packs/skills/` (keep the same basename).
2. Replace the `*.reference.json` with a `*.skill.json` of the same `id`:
   - keep `id`, `version`, `name`, and `triggerRules` as-is;
   - rename `summary` to `description`.
3. Delete the old `Packs/references/` files.

The `triggerRules` semantics are unchanged: a rule with `pathGlobs` and/or `skillTags` loads the body when a session's
inputs match those paths or tags.

```json
{
  "id" : "cli-change-checklist",
  "version" : "1.0",
  "name" : "CLI Change Checklist",
  "description" : "Triggered checklist for small CLI changes.",
  "triggerRules" : [
    { "pathGlobs" : ["**/*.swift"], "skillTags" : ["cli"] }
  ]
}
```

Or author it fresh so the formatter owns the layout:

```bash
personakit create skill --id cli-change-checklist --name "CLI Change Checklist" \
  --path-glob "**/*.swift" --skill-tag cli --body "$(cat old-checklist.md)"
```

### 2. Essentials → Always-On Grounding Skills (Or Persona Fields)

A v1 essential was standing content injected into every contract. Split each essential by what it actually is:

- **Standing grounding** (style guides, boundaries, checklists that always apply): rewrite as an **always-on grounding
  skill**. That is a skill whose single trigger rule has no path or tag conditions, so it matches unconditionally. The
  `--always-on` flag emits the empty rule for you.

  ```bash
  personakit create skill --id contract-boundaries --name "Contract Boundaries" \
    --always-on --body "$(cat Packs/essentials/contract-boundaries.md)"
  ```

  The resulting `*.skill.json` carries `"triggerRules": [ {} ]`; the empty object is the explicit always-on signal.

- **Identity or framing text** about who the agent is or the world it runs in: move it into **persona fields** instead
  of a skill. Environmental facts ("runs in a sandboxed macOS app", "no network") belong in the new persona
  `environment` array; responsibilities, values, and non-goals belong in their existing persona fields.

Then delete `Packs/essentials/`.

A grounding-skill body must have at least one trigger. `create skill` refuses a `--body` with no `--path-glob`,
`--skill-tag`, or `--always-on`, so a body cannot be silently dropped.

### 3. Intent Templates → Directive Fields

A v1 intent template held reusable `parameters`, `parameterConstraints`, `includesEssentialIds`, `requiresSkillIds`,
`referenceIds`, and `risk`, and a directive pointed at it through `requiresIntentTemplateIds`. In v2 the directive owns
that content directly.

For each directive that referenced an intent template:

1. Copy the template's `parameters` onto the directive's new `parameters` field.
2. Copy the template's `risk` onto the directive's `risk` field.
3. Union the template's `requiresSkillIds` into the directive's `requiresSkillIds`.
4. Whatever the template pulled in via `includesEssentialIds` / `referenceIds` is now grounding skills (steps 1-2), so
   they resolve automatically by trigger rather than by an explicit id list. Drop the id lists.
5. Delete `requiresIntentTemplateIds` and `referenceIds` from the directive.
6. Delete the intent-template files.

If two directives shared one intent template, the shared content is duplicated onto both. That is intended: v2 has no
shared intent layer.

### 4. Persona And Directive Cleanup

- **Persona**: add an `environment` array if you moved environmental framing out of an essential. Everything else is
  unchanged. `environment` is optional; omit it if there is nothing to say.
- **Directive**: remove any `requiresIntentTemplateIds` or `referenceIds` keys. These fields no longer exist in v2, but
  `validate` will *not* flag them: unknown keys are silently ignored, so a directive that still carries them passes
  validation while the data does nothing. Delete them by inspection (`grep -rl requiresIntentTemplateIds .personakit`),
  not by trusting `validate` to catch them.

### 5. Kits

A v1 kit could bundle `essentialIds`, `referenceIds`, `intentTemplateIds`, and `skillIds`. In v2 a kit bundles only
`skillIds`. For each kit:

1. The essentials and references it listed are now grounding skills (steps 1-2). Add their skill ids to `skillIds`.
2. Intent templates are gone; a kit no longer carries directive-shaped content. Drop `intentTemplateIds`; that content
   lives on the directive now.
3. Delete the `essentialIds`, `referenceIds`, and `intentTemplateIds` keys.

`essentialIds` is no longer required, so this only shrinks the file.

### 6. Sessions

No changes. Sessions still tie `personaId` + `directiveId` together, and `kitOverrides` still *merges* with the
persona's `defaultKitIds` rather than replacing them.

## CLI Command Changes

| PersonaKit 1 | PersonaKit 2 | Notes |
| --- | --- | --- |
| `personakit resolve-references` | `personakit resolve-grounding-skills` | Same idea, renamed for the new vocabulary. |
| `personakit create intent` | *(removed)* | Fold into the directive. |
| `personakit create reference` | `personakit create skill --path-glob/--skill-tag --body` | References are grounding skills now. |
| `personakit create essential` | `personakit create skill --always-on --body`, or persona fields | Split by standing grounding vs. identity. |
| — | `personakit checks` | Derive the read-only checks manifest from a resolved contract. |
| — | `personakit enforce install` | Project a session contract into Claude Code PreToolUse enforcement (explicit, idempotent). |
| — | `personakit hook-check` | Evaluate a PreToolUse call against a frozen checks manifest. |

`create` now offers exactly: `persona`, `kit`, `directive`, `skill`, `session`. Run `personakit schema <entity>` to see
required fields before hand-editing.

## Export Shape Changes

If anything consumes the exported Markdown by section heading, note the renames:

- `# Available References` → `# Available Skills`
- `# Expanded References` → `# Expanded Skills`
- `# Essentials` → removed (its content now appears under `# Persona` as an `Environment` block, or as a grounding
  skill).
- `# Intent Templates` → removed (folded into `# Directive`).
- `# Boundaries` → **new**: the checks-manifest projection listing each guardrail and how a host can enforce it.

## Verify The Migration

Run these against the migrated root and read the output before trusting it:

```bash
personakit validate --root <path>
personakit orphans --root <path>
personakit contract --root <path> --session <id>
personakit export  --root <path> --session <id>
```

- `validate` must pass, but understand its limits. It catches *missing required fields* and *dangling id references*
  among known fields (for example a `skillIds` entry pointing to a skill you deleted). It does **not** catch leftover v1
  keys (`requiresIntentTemplateIds`, `referenceIds`, `essentialIds`, `intentTemplateIds`): unknown keys are silently
  ignored, and a v1 file already satisfies every v2-required field, so an unmigrated directive or kit can pass a green
  `validate` with dead keys still in it. It also does not flag stray `Packs/references` or `Packs/essentials`
  directories; they are simply not loaded. Remove leftover keys and directories by inspection, not by trusting `validate`.
- `orphans` catches skills or kits nothing references after the rewrite. Personas and directives are flagged but stay
  invocable directly, so review before deleting.
- Diff the old and new exports for the same session. This is the real safety net for a migration: because a kit's old
  `essentialIds` / `referenceIds` are no longer decoded, dropping those files without adding the replacement skill ids to
  `skillIds` makes the grounding vanish from the contract with **no validation error anywhere**. Expect the heading
  renames above and a new `# Boundaries` section; the substantive role, rules, grounding, and stop points should carry
  over. If grounding text disappeared, a reference or essential did not become a grounding skill with a matching trigger.

If validation fails, fix the pack and re-run rather than editing the exported Markdown. The export is derived; the packs
are the source.

## Related Docs

- [PersonaKit For Agents](./agent-guide.md) — the steady-state v2 model and vocabulary.
- [PersonaKit MCP Guide](./mcp.md)
- [Repository Overview](../README.md)
