#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
export SWIFT_BUILD_CACHE_PATH="$ROOT_DIR/.build/swift-build-cache"

echo "==> swift test"
swift test

echo "==> schema validation (Examples/ against Schema/personakit.schema.json)"
swift run personakit-validate

echo "==> CLI list"
swift run personakit list

echo "==> CLI compose smoke test"
swift run personakit compose --persona senior-ios-engineer --context "Release check" --goal "Smoke test" --task "Confirm output"

echo "Release check completed."
