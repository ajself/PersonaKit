#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
Usage:
  Scripts/complete-worktree.sh [--branch <branch>] [--worktree <path>] [--main <main-branch>] [--no-cleanup]

Description:
  Complete a feature worktree/branch locally:
  1) Require clean feature worktree.
  2) Rebase feature branch onto local main branch (no fetch).
  3) Fast-forward merge feature branch into main.
  4) Verify feature branch is ancestor of main.
  5) Remove feature worktree and delete feature branch (unless --no-cleanup).

Options:
  --branch <branch>     Feature branch to complete. Defaults to current branch in --worktree.
  --worktree <path>     Feature worktree path. Defaults to worktree currently on --branch.
  --main <branch>       Main integration branch. Default: main.
  --no-cleanup          Keep feature worktree and branch after merge.
  -h, --help            Show help.
EOF
}

die() {
  printf "complete-worktree: %s\n" "$*" >&2
  exit 1
}

worktree_for_branch() {
  local branch_name="$1"
  local branch_ref="refs/heads/$branch_name"

  git worktree list --porcelain | awk -v target_ref="$branch_ref" '
    $1 == "worktree" { wt = $2 }
    $1 == "branch" && $2 == target_ref { print wt; exit 0 }
  '
}

feature_branch=""
feature_worktree=""
main_branch="main"
cleanup_mode="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      [[ $# -ge 2 ]] || die "Missing value for --branch."
      feature_branch="$2"
      shift 2
      ;;
    --worktree)
      [[ $# -ge 2 ]] || die "Missing value for --worktree."
      feature_worktree="$2"
      shift 2
      ;;
    --main)
      [[ $# -ge 2 ]] || die "Missing value for --main."
      main_branch="$2"
      shift 2
      ;;
    --no-cleanup)
      cleanup_mode="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if [[ -z "$feature_worktree" && -z "$feature_branch" ]]; then
  feature_worktree="$(git rev-parse --show-toplevel)"
  feature_branch="$(git -C "$feature_worktree" rev-parse --abbrev-ref HEAD)"
fi

if [[ -z "$feature_branch" ]]; then
  feature_branch="$(git -C "$feature_worktree" rev-parse --abbrev-ref HEAD)"
fi

if [[ -z "$feature_worktree" ]]; then
  feature_worktree="$(worktree_for_branch "$feature_branch")"
fi

[[ -n "$feature_worktree" ]] || die "Unable to resolve feature worktree."
[[ -d "$feature_worktree" ]] || die "Feature worktree does not exist: $feature_worktree"

if [[ "$feature_branch" == "$main_branch" ]]; then
  die "Feature branch and main branch are the same ($main_branch)."
fi

if ! git show-ref --verify --quiet "refs/heads/$feature_branch"; then
  die "Feature branch does not exist: $feature_branch"
fi

if ! git show-ref --verify --quiet "refs/heads/$main_branch"; then
  die "Main branch does not exist: $main_branch"
fi

active_feature_branch="$(git -C "$feature_worktree" rev-parse --abbrev-ref HEAD)"
if [[ "$active_feature_branch" != "$feature_branch" ]]; then
  die "Feature worktree HEAD is '$active_feature_branch', expected '$feature_branch'."
fi

if [[ -n "$(git -C "$feature_worktree" status --short)" ]]; then
  die "Feature worktree has uncommitted changes: $feature_worktree"
fi

main_worktree="$(worktree_for_branch "$main_branch")"
[[ -n "$main_worktree" ]] || die "No worktree found with $main_branch checked out."
[[ -d "$main_worktree" ]] || die "Main worktree does not exist: $main_worktree"

active_main_branch="$(git -C "$main_worktree" rev-parse --abbrev-ref HEAD)"
if [[ "$active_main_branch" != "$main_branch" ]]; then
  die "Main worktree HEAD is '$active_main_branch', expected '$main_branch'."
fi

if [[ -n "$(git -C "$main_worktree" status --short)" ]]; then
  die "Main worktree has uncommitted changes: $main_worktree"
fi

echo "Rebasing $feature_branch onto $main_branch..."
git -C "$feature_worktree" rebase "$main_branch"

echo "Fast-forward merging $feature_branch into $main_branch..."
git -C "$main_worktree" merge --ff-only "$feature_branch"

if ! git -C "$main_worktree" merge-base --is-ancestor "$feature_branch" "$main_branch"; then
  die "Verification failed: $feature_branch is not an ancestor of $main_branch after merge."
fi

main_head="$(git -C "$main_worktree" rev-parse --short "$main_branch")"
echo "Verified: $main_branch now includes $feature_branch at $main_head."

if [[ "$cleanup_mode" != "true" ]]; then
  echo "Cleanup skipped (--no-cleanup)."
  exit 0
fi

if [[ "$feature_worktree" == "$main_worktree" ]]; then
  die "Refusing cleanup: feature and main worktree are the same path."
fi

echo "Removing feature worktree: $feature_worktree"
cd /
git -C "$main_worktree" worktree remove "$feature_worktree"

echo "Deleting feature branch: $feature_branch"
git -C "$main_worktree" branch -D "$feature_branch"

echo "Local worktree completion complete."
