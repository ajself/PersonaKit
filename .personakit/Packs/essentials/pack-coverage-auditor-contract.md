# Pack Coverage Auditor Contract

Use this essential to detect under-covered or orphaned pack graph edges before
they become workflow drift.

## Purpose

1. Validate cross-entity references across personas, kits, directives, intents,
   skills, essentials, and sessions.
2. Surface unresolved references deterministically.
3. Keep coverage snapshots machine-readable for trend tracking.

## Canonical Files

1. `Docs/Development/logs/gardening-pack-coverage.schema.json`
2. `Docs/Development/logs/gardening-pack-coverage.jsonl`

## Required Checks

1. Persona `defaultKitIds` resolve to known kits.
2. Kit `essentialIds` resolve to known essentials.
3. Intent `includesEssentialIds` and `requiresSkillIds` resolve.
4. Directive `requiresIntentTemplateIds` and `requiresSkillIds` resolve.
5. Session `personaId` and `directiveId` resolve.

## Guardrails

1. Coverage snapshots are append-only and deterministic.
2. Any unresolved reference is a failing signal until resolved or explicitly
   deprecated.
