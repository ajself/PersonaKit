#!/usr/bin/env bash
set -euo pipefail

manifest_path="Docs/PersonaKit/Development/worktree-lane-approvals.json"
branch_override=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest_path="$2"
      shift 2
      ;;
    --branch)
      branch_override="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--manifest path] [--branch branch]" >&2
      exit 64
      ;;
  esac
done

export WORKTREE_LANE_MANIFEST="$manifest_path"
export WORKTREE_LANE_BRANCH="$branch_override"

python3 - <<'PY'
import hashlib
import json
import os
import subprocess
from pathlib import Path


def render_lane_note(lane: dict, branch: str, manifest_digest: str) -> str:
    status = lane.get("status")
    mode = lane.get("authorizationMode")
    scope_boundary = lane.get("scopeBoundary")
    milestone = lane.get("milestone")
    workspace_scope = lane.get("workspaceScope")
    source_branch = lane.get("sourceBranch")
    promotion_target = lane.get("promotionTarget")
    plan_refs = lane.get("planRefs", [])
    stop_reasons = lane.get("stopReasons", [])

    status_label = "Exploratory" if status == "exploratory" else "Active"
    plan_lines = "\n".join(f"- `{ref}`" for ref in plan_refs)
    stop_lines = "\n".join(f"- {reason}" for reason in stop_reasons)

    return f"""# {milestone} Lane

Status: {status_label}
Owner: Samwise
Branch: `{branch}`
Authorization Mode: `{mode}`
Workspace Scope: {workspace_scope}
Source Branch: `{source_branch or '-'}`
Promotion Target: `{promotion_target or '-'}`
Manifest Digest: `{manifest_digest}`

## Purpose

Keep the approved lane scope visible inside the worktree so Samwise can resume
execution without re-asking whether standing authority applies here.

## Scope Boundary

{scope_boundary}

## Plan References

{plan_lines}

## Stop And Ask AJ When

{stop_lines}

## Startup Checklist

1. Run `Scripts/check-worktree-lane.sh`.
2. Re-read the plan references listed above.
3. Confirm the next bounded work item still fits the lane scope boundary.
4. Run baseline validation before broad implementation changes when code work is
   about to begin.

## Promotion Rule

This lane does not promote itself. AJ decides when or whether work moves beyond
this lane or back toward `main`.
"""


manifest_path = Path(os.environ["WORKTREE_LANE_MANIFEST"])
branch_override = os.environ.get("WORKTREE_LANE_BRANCH", "").strip()

if not manifest_path.exists():
    print("WORKTREE_LANE_CHECK:FAIL")
    print(f"missing manifest {manifest_path}")
    raise SystemExit(1)

data = json.loads(manifest_path.read_text())
lanes = data.get("lanes")

if not isinstance(lanes, list):
    print("WORKTREE_LANE_CHECK:FAIL")
    print("manifest field 'lanes' must be a list")
    raise SystemExit(1)

branch = branch_override
if not branch:
    branch = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()

matches = [lane for lane in lanes if isinstance(lane, dict) and lane.get("branch") == branch]

if not matches:
    print("WORKTREE_LANE_CHECK:FAIL")
    print(f"branch {branch!r} is not recorded in {manifest_path}")
    raise SystemExit(1)

if len(matches) > 1:
    print("WORKTREE_LANE_CHECK:FAIL")
    print(f"branch {branch!r} has multiple lane entries in {manifest_path}")
    raise SystemExit(1)

lane = matches[0]
errors: list[str] = []

allowed_status = {"protected", "approved", "exploratory"}
allowed_modes = {"per-commit-approval", "worktree-auto-commit-approved"}

status = lane.get("status")
mode = lane.get("authorizationMode")
lane_id = lane.get("laneId")
workspace_scope = lane.get("workspaceScope")
milestone = lane.get("milestone")
scope_boundary = lane.get("scopeBoundary")
source_branch = lane.get("sourceBranch")
promotion_target = lane.get("promotionTarget")
lane_note_path = lane.get("laneNotePath")
plan_refs = lane.get("planRefs", [])
stop_reasons = lane.get("stopReasons", [])
manifest_digest = hashlib.sha256(
    json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()[:12]

if status not in allowed_status:
    errors.append(f"lane {lane_id!r} has unsupported status {status!r}")

if mode not in allowed_modes:
    errors.append(f"lane {lane_id!r} has unsupported authorizationMode {mode!r}")

if branch == "main" and mode != "per-commit-approval":
    errors.append("branch 'main' must remain in per-commit-approval mode")

if status == "protected" and mode == "worktree-auto-commit-approved":
    errors.append(f"protected lane {lane_id!r} cannot allow auto-commit mode")

if not isinstance(plan_refs, list) or not plan_refs:
    errors.append(f"lane {lane_id!r} must list at least one planRefs entry")
else:
    for ref in plan_refs:
        if not isinstance(ref, str) or not Path(ref).exists():
            errors.append(f"lane {lane_id!r} references missing planRef {ref!r}")

if not isinstance(stop_reasons, list) or not stop_reasons:
    errors.append(f"lane {lane_id!r} must list at least one stopReasons entry")

if not isinstance(lane_id, str) or not lane_id:
    errors.append("laneId must be a non-empty string")

if not isinstance(workspace_scope, str) or not workspace_scope:
    errors.append(f"lane {lane_id!r} must define workspaceScope")

if not isinstance(milestone, str) or not milestone:
    errors.append(f"lane {lane_id!r} must define milestone")

if not isinstance(scope_boundary, str) or not scope_boundary:
    errors.append(f"lane {lane_id!r} must define scopeBoundary")

note_status = "n/a"
if isinstance(lane_note_path, str) and lane_note_path:
    note_path = Path(lane_note_path)
    if note_path.exists():
        expected_note = render_lane_note(lane, branch, manifest_digest)
        actual_note = note_path.read_text()
        note_status = "present"
        if actual_note != expected_note:
            errors.append(
                f"lane {lane_id!r} note {lane_note_path!r} is stale; rerun bootstrap-worktree-lane.sh"
            )
            note_status = "stale"
    else:
        errors.append(
            f"lane {lane_id!r} note {lane_note_path!r} is missing; run bootstrap-worktree-lane.sh"
        )
        note_status = "missing"

if errors:
    print("WORKTREE_LANE_CHECK:FAIL")
    for error in errors:
        print(error)
    raise SystemExit(1)

standing_authority_allowed = mode == "worktree-auto-commit-approved"
if not standing_authority_allowed:
    print("WORKTREE_LANE_CHECK:FAIL")
    print(f"branch={branch}")
    print(f"laneId={lane_id}")
    print(f"status={status}")
    print(f"authorizationMode={mode}")
    print(
        "standing authority is not active for this lane; fall back to explicit AJ approval"
    )
    raise SystemExit(1)

print("WORKTREE_LANE_CHECK:PASS")
print(f"branch={branch}")
print(f"laneId={lane_id}")
print(f"status={status}")
print(f"authorizationMode={mode}")
print(f"workspaceScope={workspace_scope}")
print(f"milestone={milestone}")
print(f"scopeBoundary={scope_boundary}")
print(f"sourceBranch={source_branch or '-'}")
print(f"promotionTarget={promotion_target or '-'}")
print(f"manifestDigest={manifest_digest}")
print(f"laneNotePath={lane_note_path or '-'}")
print(f"laneNoteStatus={note_status}")
print(f"planRefCount={len(plan_refs)}")
print(f"stopReasonCount={len(stop_reasons)}")
PY
