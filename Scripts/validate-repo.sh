#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

kit_root="Fixtures/kit-root"
persona_id="senior-swiftui-engineer"
directive_id="apply-style"
session_id="senior-swiftui-engineer_apply-style"

validate_tmp_root="${PERSONAKIT_VALIDATE_TMP_ROOT:-${TMPDIR:-/tmp}}"
work_dir="${validate_tmp_root}/personakit-validate"
cleanup_on_success="true"
unchecked_sendable_approval_file="Docs/PersonaKit/Architecture/unchecked-sendable-approvals.txt"

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
if [[ ! -f "$unchecked_sendable_approval_file" ]]; then
  echo "Missing approval registry: $unchecked_sendable_approval_file"
  exit 1
fi

unchecked_matches_file="$work_dir/unchecked-sendable-matches.txt"
unauthorized_matches_file="$work_dir/unchecked-sendable-unapproved.txt"

rg -n --no-heading "@unchecked[[:space:]]+Sendable" App Sources Tests >"$unchecked_matches_file" || true
: >"$unauthorized_matches_file"

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  match_path="${match%%:*}"
  match_remainder="${match#*:}"
  match_line="${match_remainder%%:*}"
  match_id="${match_path}:${match_line}"

  if ! grep -Fxq "$match_id" "$unchecked_sendable_approval_file"; then
    printf '%s\n' "$match" >>"$unauthorized_matches_file"
  fi
done <"$unchecked_matches_file"

if [[ -s "$unauthorized_matches_file" ]]; then
  echo "Unapproved @unchecked Sendable usage detected."
  echo "Repository policy requires explicit owner approval for each usage."
  echo "Add an exact path:line entry to $unchecked_sendable_approval_file only when approved."
  cat "$unauthorized_matches_file"
  exit 1
fi

echo "Running swift test..."
swift test

echo "Checking generated workstream docs..."
swift run personakit workstream-docs --root .personakit --check

echo "Validating kit..."
swift run personakit validate --root "$kit_root"

echo "Checking export determinism..."
swift run personakit export --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/export-1.md"
swift run personakit export --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/export-2.md"
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
swift run personakit graph --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/graph-1.txt"
swift run personakit graph --root "$kit_root" --persona "$persona_id" --directive "$directive_id" > "$work_dir/graph-2.txt"
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
