#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

kit_root="Fixtures/kit-root"
persona_id="senior-swiftui-engineer"
directive_id="apply-style"
session_id="senior-swiftui-engineer_apply-style"

validate_user="${USER:-unknown}"
validate_tmp_root="${PERSONAKIT_VALIDATE_TMP_ROOT:-/tmp/personakit-$validate_user-validate}"
work_dir="${validate_tmp_root}/personakit-validate"
cleanup_on_success="true"
# Keep SwiftPM writes out of user caches and the repo tree so sandboxed
# validation is reproducible and scope-discovery tests use isolated roots.
swiftpm_cache_root="${PERSONAKIT_SWIFTPM_CACHE_ROOT:-$validate_tmp_root/swiftpm}"
swiftpm_tmp_dir="${PERSONAKIT_SWIFTPM_TMPDIR:-$swiftpm_cache_root/tmp}"
export CLANG_MODULE_CACHE_PATH="$swiftpm_cache_root/clang-module-cache"
export TMPDIR="$swiftpm_tmp_dir"
swiftpm_flags=(
  --cache-path "$swiftpm_cache_root/cache"
  --config-path "$swiftpm_cache_root/configuration"
  --security-path "$swiftpm_cache_root/security"
  --manifest-cache local
  --disable-sandbox
  -Xswiftc -module-cache-path
  -Xswiftc "$swiftpm_cache_root/module-cache"
  -Xcc "-fmodules-cache-path=$swiftpm_cache_root/clang-module-cache"
)

rm -rf "$work_dir"
mkdir -p "$work_dir" \
  "$swiftpm_cache_root/cache" \
  "$swiftpm_cache_root/clang-module-cache" \
  "$swiftpm_cache_root/configuration" \
  "$swiftpm_cache_root/module-cache" \
  "$swiftpm_cache_root/security" \
  "$swiftpm_tmp_dir"

cleanup() {
  if [[ "$cleanup_on_success" == "true" ]]; then
    rm -rf "$work_dir"
  else
    echo "Outputs preserved at: $work_dir"
  fi
}
trap cleanup EXIT

echo "Checking formatting..."
make format-check

echo "Checking module boundaries..."
if find Sources/Shared/ContextCore -maxdepth 1 -type f -name 'Workspace*.swift' | grep -q .; then
  echo "ContextCore must not contain workspace-prefixed source files."
  find Sources/Shared/ContextCore -maxdepth 1 -type f -name 'Workspace*.swift' | sort
  exit 1
fi

if rg -n "import ContextWorkspaceCore" Sources/Shared/ContextCore >/dev/null; then
  echo "ContextCore must not import ContextWorkspaceCore."
  rg -n "import ContextWorkspaceCore" Sources/Shared/ContextCore || true
  exit 1
fi

echo "Checking @unchecked Sendable policy..."
unchecked_matches_file="$work_dir/unchecked-sendable-matches.txt"
unchecked_search_roots=()

for search_root in App Sources Tests; do
  if [[ -d "$search_root" ]]; then
    unchecked_search_roots+=("$search_root")
  fi
done

if [[ ${#unchecked_search_roots[@]} -eq 0 ]]; then
  echo "No source directories available for @unchecked Sendable scanning."
  exit 1
fi

rg -n --no-heading \
  --glob '*.swift' \
  "@unchecked[[:space:]]+Sendable" \
  "${unchecked_search_roots[@]}" >"$unchecked_matches_file" || true

if [[ -s "$unchecked_matches_file" ]]; then
  echo "@unchecked Sendable is not allowed in this repository."
  cat "$unchecked_matches_file"
  exit 1
fi

echo "Running swift test..."
swift test "${swiftpm_flags[@]}"

echo "Validating kit..."
swift run "${swiftpm_flags[@]}" personakit validate --root "$kit_root"

echo "Checking export determinism..."
swift run "${swiftpm_flags[@]}" personakit export --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/export-1.md"
swift run "${swiftpm_flags[@]}" personakit export --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/export-2.md"
if ! cmp -s "$work_dir/export-1.md" "$work_dir/export-2.md"; then
  echo "Export output is not deterministic."
  diff -u "$work_dir/export-1.md" "$work_dir/export-2.md" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Checking export determinism (session)..."
swift run "${swiftpm_flags[@]}" personakit export --root "$kit_root" --session "$session_id" > "$work_dir/export-session-1.md"
swift run "${swiftpm_flags[@]}" personakit export --root "$kit_root" --session "$session_id" > "$work_dir/export-session-2.md"
if ! cmp -s "$work_dir/export-session-1.md" "$work_dir/export-session-2.md"; then
  echo "Export session output is not deterministic."
  diff -u "$work_dir/export-session-1.md" "$work_dir/export-session-2.md" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Checking graph determinism..."
swift run "${swiftpm_flags[@]}" personakit graph --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/graph-1.txt"
swift run "${swiftpm_flags[@]}" personakit graph --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/graph-2.txt"
if ! cmp -s "$work_dir/graph-1.txt" "$work_dir/graph-2.txt"; then
  echo "Graph output is not deterministic."
  diff -u "$work_dir/graph-1.txt" "$work_dir/graph-2.txt" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Checking graph determinism (session)..."
swift run "${swiftpm_flags[@]}" personakit graph --root "$kit_root" --session "$session_id" > "$work_dir/graph-session-1.txt"
swift run "${swiftpm_flags[@]}" personakit graph --root "$kit_root" --session "$session_id" > "$work_dir/graph-session-2.txt"
if ! cmp -s "$work_dir/graph-session-1.txt" "$work_dir/graph-session-2.txt"; then
  echo "Graph session output is not deterministic."
  diff -u "$work_dir/graph-session-1.txt" "$work_dir/graph-session-2.txt" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Validation complete."
