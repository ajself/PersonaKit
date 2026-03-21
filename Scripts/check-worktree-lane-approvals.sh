#!/usr/bin/env bash
set -euo pipefail

manifest_path="Docs/PersonaKit/Development/worktree-lane-approvals.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest_path="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--manifest path]" >&2
      exit 64
      ;;
  esac
done

export WORKTREE_LANE_MANIFEST="$manifest_path"

python3 - <<'PY'
import json
import os
from pathlib import Path

manifest_path = Path(os.environ["WORKTREE_LANE_MANIFEST"])

if not manifest_path.exists():
    print("WORKTREE_LANE_APPROVALS_CHECK:FAIL")
    print(f"missing manifest {manifest_path}")
    raise SystemExit(1)

data = json.loads(manifest_path.read_text())
errors: list[str] = []

if data.get("version") != 1:
    errors.append(f"manifest version must be 1, found {data.get('version')!r}")

approval_source = data.get("approvalSource")
if not isinstance(approval_source, str) or not approval_source:
    errors.append("approvalSource must be a non-empty string")

lanes = data.get("lanes")
if not isinstance(lanes, list) or not lanes:
    errors.append("lanes must be a non-empty list")
    lanes = []

allowed_status = {"protected", "approved", "exploratory"}
allowed_modes = {"per-commit-approval", "worktree-auto-commit-approved"}
seen_lane_ids: set[str] = set()
seen_branches: set[str] = set()

for idx, lane in enumerate(lanes, start=1):
    prefix = f"lane[{idx}]"
    if not isinstance(lane, dict):
        errors.append(f"{prefix} must be an object")
        continue

    lane_id = lane.get("laneId")
    branch = lane.get("branch")
    status = lane.get("status")
    mode = lane.get("authorizationMode")
    workspace_scope = lane.get("workspaceScope")
    milestone = lane.get("milestone")
    scope_boundary = lane.get("scopeBoundary")
    start_point = lane.get("startPoint")
    source_branch = lane.get("sourceBranch")
    promotion_target = lane.get("promotionTarget")
    lane_note_path = lane.get("laneNotePath")
    plan_refs = lane.get("planRefs")
    stop_reasons = lane.get("stopReasons")

    for field_name, value in [
        ("laneId", lane_id),
        ("branch", branch),
        ("workspaceScope", workspace_scope),
        ("milestone", milestone),
        ("scopeBoundary", scope_boundary),
    ]:
        if not isinstance(value, str) or not value:
            errors.append(f"{prefix} field {field_name!r} must be a non-empty string")

    if isinstance(lane_id, str):
        if lane_id in seen_lane_ids:
            errors.append(f"{prefix} duplicate laneId {lane_id!r}")
        seen_lane_ids.add(lane_id)

    if isinstance(branch, str):
        if branch in seen_branches:
            errors.append(f"{prefix} duplicate branch {branch!r}")
        seen_branches.add(branch)

    if status not in allowed_status:
        errors.append(f"{prefix} unsupported status {status!r}")

    if mode not in allowed_modes:
        errors.append(f"{prefix} unsupported authorizationMode {mode!r}")

    if isinstance(plan_refs, list):
        if not plan_refs:
            errors.append(f"{prefix} must define at least one planRefs entry")
        for ref in plan_refs:
            if not isinstance(ref, str) or not ref:
                errors.append(f"{prefix} has invalid planRef {ref!r}")
            elif not Path(ref).exists():
                errors.append(f"{prefix} references missing planRef {ref!r}")
    else:
        errors.append(f"{prefix} field 'planRefs' must be a non-empty list")

    if isinstance(stop_reasons, list):
        if not stop_reasons:
            errors.append(f"{prefix} must define at least one stopReasons entry")
        for reason in stop_reasons:
            if not isinstance(reason, str) or not reason:
                errors.append(f"{prefix} has invalid stop reason {reason!r}")
    else:
        errors.append(f"{prefix} field 'stopReasons' must be a non-empty list")

    if branch == "main":
        if status != "protected":
            errors.append(f"{prefix} branch 'main' must use status 'protected'")
        if mode != "per-commit-approval":
            errors.append(f"{prefix} branch 'main' must use per-commit-approval")
        if lane_note_path is not None:
            errors.append(f"{prefix} branch 'main' must not define laneNotePath")
        if start_point is not None:
            errors.append(f"{prefix} branch 'main' must not define startPoint")

    if status in {"approved", "exploratory"}:
        if not isinstance(lane_note_path, str) or not lane_note_path:
            errors.append(f"{prefix} must define laneNotePath for executable lanes")
        if source_branch is None and start_point is None:
            errors.append(
                f"{prefix} executable lanes must define sourceBranch or startPoint"
            )

    if status == "protected" and source_branch is not None:
        errors.append(f"{prefix} protected lanes should not define sourceBranch")

    if source_branch is not None and not isinstance(source_branch, str):
        errors.append(f"{prefix} sourceBranch must be null or string")

    if start_point is not None and (not isinstance(start_point, str) or not start_point):
        errors.append(f"{prefix} startPoint must be null or non-empty string")

    if promotion_target is not None and not isinstance(promotion_target, str):
        errors.append(f"{prefix} promotionTarget must be null or string")

if errors:
    print("WORKTREE_LANE_APPROVALS_CHECK:FAIL")
    for error in errors:
        print(error)
    raise SystemExit(1)

print("WORKTREE_LANE_APPROVALS_CHECK:PASS")
print(f"manifest={manifest_path}")
print(f"laneCount={len(lanes)}")
PY
