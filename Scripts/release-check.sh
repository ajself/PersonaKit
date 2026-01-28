#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
DERIVED_DATA_PATH="$ROOT_DIR/.build/DerivedData"

echo "==> xcodebuild test (PersonaKitApp)"
xcodebuild -project PersonaKit.xcodeproj -scheme PersonaKitApp -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" test

build_target() {
  xcodebuild -project PersonaKit.xcodeproj -target "$1" -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" build
}

target_executable() {
  local target="$1"
  local build_settings
  build_settings="$(xcodebuild -project PersonaKit.xcodeproj -target "$target" -configuration Debug -derivedDataPath "$DERIVED_DATA_PATH" -showBuildSettings)"
  local target_dir
  target_dir="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/TARGET_BUILD_DIR/ {print $2; exit}')"
  local exec_path
  exec_path="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/EXECUTABLE_PATH/ {print $2; exit}')"
  printf "%s/%s\n" "$target_dir" "$exec_path"
}

build_target "PersonaKitSchemaValidate"
validator="$(target_executable "PersonaKitSchemaValidate")"
echo "==> schema validation (Examples/ against Schema/personakit.schema.json)"
"$validator"

build_target "PersonaKitCLI"
cli="$(target_executable "PersonaKitCLI")"
echo "==> CLI list"
"$cli" list

echo "==> CLI compose smoke test"
"$cli" compose --persona senior-ios-engineer --context "Release check" --goal "Smoke test" --task "Confirm output"

echo "Release check completed."
