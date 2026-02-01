#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

kit_root="Fixtures/kit-root"
persona_id="senior-swiftui-engineer"
task_id="apply-style"
session_id="senior-swiftui-engineer_apply-style"

work_dir="${TMPDIR:-/tmp}/personakit-validate"
cleanup_on_success="true"

rm -rf "$work_dir"
mkdir -p "$work_dir"

cleanup() {
  if [[ "$cleanup_on_success" == "true" ]]; then
    rm -rf "$work_dir"
  else
    echo "Outputs preserved at: $work_dir"
  fi
}
trap cleanup EXIT

echo "Running swift test..."
swift test

echo "Validating kit..."
swift run personakit validate --root "$kit_root"

echo "Checking export determinism..."
swift run personakit export --root "$kit_root" --persona "$persona_id" --task "$task_id" > "$work_dir/export-1.md"
swift run personakit export --root "$kit_root" --persona "$persona_id" --task "$task_id" > "$work_dir/export-2.md"
if ! cmp -s "$work_dir/export-1.md" "$work_dir/export-2.md"; then
  echo "Export output is not deterministic."
  diff -u "$work_dir/export-1.md" "$work_dir/export-2.md" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Checking export determinism (session)..."
swift run personakit export --root "$kit_root" --session "$session_id" > "$work_dir/export-session-1.md"
swift run personakit export --root "$kit_root" --session "$session_id" > "$work_dir/export-session-2.md"
if ! cmp -s "$work_dir/export-session-1.md" "$work_dir/export-session-2.md"; then
  echo "Export session output is not deterministic."
  diff -u "$work_dir/export-session-1.md" "$work_dir/export-session-2.md" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Checking graph determinism..."
swift run personakit graph --root "$kit_root" --persona "$persona_id" --task "$task_id" > "$work_dir/graph-1.txt"
swift run personakit graph --root "$kit_root" --persona "$persona_id" --task "$task_id" > "$work_dir/graph-2.txt"
if ! cmp -s "$work_dir/graph-1.txt" "$work_dir/graph-2.txt"; then
  echo "Graph output is not deterministic."
  diff -u "$work_dir/graph-1.txt" "$work_dir/graph-2.txt" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Checking graph determinism (session)..."
swift run personakit graph --root "$kit_root" --session "$session_id" > "$work_dir/graph-session-1.txt"
swift run personakit graph --root "$kit_root" --session "$session_id" > "$work_dir/graph-session-2.txt"
if ! cmp -s "$work_dir/graph-session-1.txt" "$work_dir/graph-session-2.txt"; then
  echo "Graph session output is not deterministic."
  diff -u "$work_dir/graph-session-1.txt" "$work_dir/graph-session-2.txt" || true
  cleanup_on_success="false"
  exit 1
fi

echo "Validation complete."
