# Release Checklist

## Tests
- Run `swift test`

## Manual QA
- Launch app: `swift run PersonaKitApp`
- Select a persona and verify prompt preview updates when editing sections.
- Open JSON panel and verify syntax highlighting + Format JSON.
- Reload packs and verify selection persists (when possible).
- Run CLI:
  - `swift run personakit list`
  - `swift run personakit compose --persona <id> --context "Example" --goal "Example"`
  - `swift run personakit compose --persona <id> --resolved-json`

## Schema validation
- Run `swift run personakit-validate` to validate Examples against `Schema/personakit.schema.json`.

## Automated release check
- Run `Scripts/release-check.sh` (from repo root) to run tests, schema validation, and CLI smoke checks.
