#!/usr/bin/env bash
set -euo pipefail

manifest_path="Docs/PersonaKit/Development/worktree-lane-approvals.json"
branch_override=""
check_mode="authority"

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
    --mode)
      check_mode="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--manifest path] [--branch branch] [--mode authority|contract]" >&2
      exit 64
      ;;
  esac
done

export WORKTREE_LANE_MANIFEST="$manifest_path"
export WORKTREE_LANE_BRANCH="$branch_override"
export WORKTREE_LANE_MODE="$check_mode"

python3 - <<'PY'
import hashlib
import json
import os
import subprocess
from pathlib import Path


def render_lane_note(lane: dict, branch: str, manifest_digest: str) -> str:
    status = lane.get("status")
    mode = lane.get("authorizationMode")
    owner = lane.get("owner", "Samwise")
    owner_session_id = lane.get("ownerSessionId")
    scope_boundary = lane.get("scopeBoundary")
    milestone = lane.get("milestone")
    workspace_scope = lane.get("workspaceScope")
    start_point = lane.get("startPoint")
    source_branch = lane.get("sourceBranch")
    promotion_target = lane.get("promotionTarget")
    plan_refs = lane.get("planRefs", [])
    stop_reasons = lane.get("stopReasons", [])

    status_label = "Exploratory" if status == "exploratory" else "Active"
    plan_lines = "\n".join(f"- `{ref}`" for ref in plan_refs)
    stop_lines = "\n".join(f"- {reason}" for reason in stop_reasons)
    start_point_line = f"Start Point: `{start_point}`\n" if start_point else ""
    owner_session_line = (
        f"Owner Session: `{owner_session_id}`\n" if owner_session_id else ""
    )
    if mode == "worktree-auto-commit-approved":
        purpose = (
            f"Keep the approved lane scope visible inside the worktree so {owner} can resume\n"
            "execution without re-asking whether standing authority applies here."
        )
        startup_step_1 = "1. Run `Scripts/check-worktree-lane.sh`."
    else:
        purpose = (
            "Keep the approved lane scope and approval mode visible inside the worktree so\n"
            f"{owner} can resume execution without re-asking what contract applies here."
        )
        startup_step_1 = "1. Run `Scripts/check-worktree-lane.sh --mode contract`."

    return f"""# {milestone} Lane

Status: {status_label}
Owner: {owner}
{owner_session_line}Branch: `{branch}`
Authorization Mode: `{mode}`
Workspace Scope: {workspace_scope}
{start_point_line}Source Branch: `{source_branch or '-'}`
Promotion Target: `{promotion_target or '-'}`
Manifest Digest: `{manifest_digest}`

## Purpose

{purpose}

## Scope Boundary

{scope_boundary}

## Plan References

{plan_lines}

## Stop And Ask AJ When

{stop_lines}

## Startup Checklist

{startup_step_1}
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
check_mode = os.environ.get("WORKTREE_LANE_MODE", "authority").strip() or "authority"

if check_mode not in {"authority", "contract"}:
    print("WORKTREE_LANE_CHECK:FAIL")
    print(f"unsupported mode {check_mode!r}; expected 'authority' or 'contract'")
    raise SystemExit(1)

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

current_branch = subprocess.run(
    ["git", "rev-parse", "--abbrev-ref", "HEAD"],
    check=True,
    capture_output=True,
    text=True,
).stdout.strip()

branch = branch_override or current_branch

if check_mode == "authority" and branch_override and current_branch != branch:
    print("WORKTREE_LANE_CHECK:FAIL")
    print(
        "authority mode requires the active branch to match the requested lane "
        f"(current={current_branch!r}, requested={branch!r})"
    )
    raise SystemExit(1)

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
start_point = lane.get("startPoint")
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

if start_point is not None and (not isinstance(start_point, str) or not start_point):
    errors.append(f"lane {lane_id!r} has invalid startPoint {start_point!r}")

if status in {"approved", "exploratory"} and start_point is None and source_branch is None:
    errors.append(
        f"lane {lane_id!r} must define sourceBranch or startPoint for materialization"
    )

note_status = "n/a"
if isinstance(lane_note_path, str) and lane_note_path:
    note_path = Path(lane_note_path)
    if note_path.exists():
        expected_note = render_lane_note(lane, branch, manifest_digest)
        actual_note = note_path.read_text()
        note_status = "present"
        if actual_note != expected_note:
            note_status = "stale"
            if check_mode == "authority":
                errors.append(
                    f"lane {lane_id!r} note {lane_note_path!r} is stale; rerun bootstrap-worktree-lane.sh"
                )
    else:
        note_status = "missing"
        if check_mode == "authority":
            errors.append(
                f"lane {lane_id!r} note {lane_note_path!r} is missing; run bootstrap-worktree-lane.sh"
            )

if errors:
    print("WORKTREE_LANE_CHECK:FAIL")
    for error in errors:
        print(error)
    raise SystemExit(1)

standing_authority_allowed = mode == "worktree-auto-commit-approved"
if check_mode == "authority" and not standing_authority_allowed:
    print("WORKTREE_LANE_CHECK:FAIL")
    print(f"mode={check_mode}")
    print(f"branch={branch}")
    print(f"laneId={lane_id}")
    print(f"status={status}")
    print(f"authorizationMode={mode}")
    print(
        "standing authority is not active for this lane; fall back to explicit AJ approval"
    )
    raise SystemExit(1)

print("WORKTREE_LANE_CHECK:PASS")
print(f"mode={check_mode}")
print(f"branch={branch}")
print(f"laneId={lane_id}")
print(f"status={status}")
print(f"authorizationMode={mode}")
print(f"workspaceScope={workspace_scope}")
print(f"milestone={milestone}")
print(f"scopeBoundary={scope_boundary}")
print(f"startPoint={start_point or '-'}")
print(f"sourceBranch={source_branch or '-'}")
print(f"promotionTarget={promotion_target or '-'}")
print(f"manifestDigest={manifest_digest}")
print(f"laneNotePath={lane_note_path or '-'}")
print(f"laneNoteStatus={note_status}")
print(f"planRefCount={len(plan_refs)}")
print(f"stopReasonCount={len(stop_reasons)}")
if check_mode == "contract":
    print("authorizationState=contract-only")
else:
    print("authorizationState=standing-authority-active")
PY
