# Release Checklist

## Tests
- Run `xcodebuild -project PersonaKit.xcodeproj -scheme PersonaKitApp -configuration Debug test`

## Manual QA
- Launch app via Xcode: `open PersonaKit.xcodeproj` and run the `PersonaKitApp` scheme.
- Select a persona and verify prompt preview updates when editing sections.
- Open JSON panel and verify syntax highlighting + Format JSON.
- Reload packs and verify selection persists (when possible).
- Run CLI:
  - Build: `xcodebuild -project PersonaKit.xcodeproj -target PersonaKitCLI -configuration Debug build`
  - Resolve path: `CLI_PATH="$(xcodebuild -project PersonaKit.xcodeproj -target PersonaKitCLI -configuration Debug -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ {dir=$2} /EXECUTABLE_PATH/ {exe=$2} END {print dir "/" exe}')"`
  - `"$CLI_PATH" list`
  - `"$CLI_PATH" compose --persona <id> --context "Example" --goal "Example"`
  - `"$CLI_PATH" compose --persona <id> --resolved-json`

## Schema validation
- Build: `xcodebuild -project PersonaKit.xcodeproj -target PersonaKitSchemaValidate -configuration Debug build`
- Resolve path: `VALIDATOR_PATH="$(xcodebuild -project PersonaKit.xcodeproj -target PersonaKitSchemaValidate -configuration Debug -showBuildSettings | awk -F ' = ' '/TARGET_BUILD_DIR/ {dir=$2} /EXECUTABLE_PATH/ {exe=$2} END {print dir "/" exe}')"`
- Run `"$VALIDATOR_PATH"` to validate Examples against `Schema/personakit.schema.json`.

## Automated release check
- Run `Scripts/release-check.sh` (from repo root) to run tests, schema validation, and CLI smoke checks.
