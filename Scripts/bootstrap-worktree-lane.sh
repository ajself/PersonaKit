#!/usr/bin/env bash
set -euo pipefail

manifest_path="Docs/PersonaKit/Development/worktree-lane-approvals.json"
branch_override=""
output_override=""
force_write="0"

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
    --output)
      output_override="$2"
      shift 2
      ;;
    --force)
      force_write="1"
      shift 1
      ;;
    *)
      echo "Usage: $0 [--manifest path] [--branch branch] [--output path] [--force]" >&2
      exit 64
      ;;
  esac
done

export WORKTREE_LANE_MANIFEST="$manifest_path"
export WORKTREE_LANE_BRANCH="$branch_override"
export WORKTREE_LANE_OUTPUT="$output_override"
export WORKTREE_LANE_FORCE="$force_write"

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
    start_point = lane.get("startPoint")
    source_branch = lane.get("sourceBranch")
    promotion_target = lane.get("promotionTarget")
    plan_refs = lane.get("planRefs", [])
    stop_reasons = lane.get("stopReasons", [])

    status_label = "Exploratory" if status == "exploratory" else "Active"
    plan_lines = "\n".join(f"- `{ref}`" for ref in plan_refs)
    stop_lines = "\n".join(f"- {reason}" for reason in stop_reasons)
    start_point_line = f"Start Point: `{start_point}`\n" if start_point else ""
    if mode == "worktree-auto-commit-approved":
        purpose = (
            "Keep the approved lane scope visible inside the worktree so Samwise can resume\n"
            "execution without re-asking whether standing authority applies here."
        )
        startup_step_1 = "1. Run `Scripts/check-worktree-lane.sh`."
    else:
        purpose = (
            "Keep the approved lane scope and approval mode visible inside the worktree so\n"
            "Samwise can resume execution without re-asking what contract applies here."
        )
        startup_step_1 = "1. Run `Scripts/check-worktree-lane.sh --mode contract`."

    return f"""# {milestone} Lane

Status: {status_label}
Owner: Samwise
Branch: `{branch}`
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
output_override = os.environ.get("WORKTREE_LANE_OUTPUT", "").strip()
force_write = os.environ.get("WORKTREE_LANE_FORCE", "0") == "1"

if not manifest_path.exists():
    print("BOOTSTRAP_WORKTREE_LANE:FAIL")
    print(f"missing manifest {manifest_path}")
    raise SystemExit(1)

data = json.loads(manifest_path.read_text())
lanes = data.get("lanes")
if not isinstance(lanes, list):
    print("BOOTSTRAP_WORKTREE_LANE:FAIL")
    print("manifest field 'lanes' must be a list")
    raise SystemExit(1)

current_branch = subprocess.run(
    ["git", "rev-parse", "--abbrev-ref", "HEAD"],
    check=True,
    capture_output=True,
    text=True,
).stdout.strip()

branch = branch_override or current_branch
matches = [lane for lane in lanes if isinstance(lane, dict) and lane.get("branch") == branch]

if not matches:
    print("BOOTSTRAP_WORKTREE_LANE:FAIL")
    print(f"branch {branch!r} is not recorded in {manifest_path}")
    raise SystemExit(1)

if len(matches) > 1:
    print("BOOTSTRAP_WORKTREE_LANE:FAIL")
    print(f"branch {branch!r} has multiple lane entries in {manifest_path}")
    raise SystemExit(1)

lane = matches[0]
lane_id = lane.get("laneId")
status = lane.get("status")
lane_note_path = lane.get("laneNotePath")
manifest_digest = hashlib.sha256(
    json.dumps(data, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()[:12]

if status == "protected":
    print("BOOTSTRAP_WORKTREE_LANE:FAIL")
    print(f"branch {branch!r} is protected and should not be bootstrapped as an execution lane")
    raise SystemExit(1)

target_path = Path(output_override) if output_override else None
if target_path is None:
    if not isinstance(lane_note_path, str) or not lane_note_path:
        print("BOOTSTRAP_WORKTREE_LANE:FAIL")
        print(f"lane {lane_id!r} does not define laneNotePath")
        raise SystemExit(1)
    if current_branch != branch:
        print("BOOTSTRAP_WORKTREE_LANE:FAIL")
        print(
            "write mode requires the active branch to match the requested lane "
            f"(current={current_branch!r}, requested={branch!r})"
        )
        raise SystemExit(1)
    target_path = Path(lane_note_path)

content = render_lane_note(lane, branch, manifest_digest)

target_path.parent.mkdir(parents=True, exist_ok=True)

if target_path.exists() and not force_write:
    existing_content = target_path.read_text()
    if existing_content == content:
        print("BOOTSTRAP_WORKTREE_LANE:PASS")
        print(f"branch={branch}")
        print(f"laneId={lane_id}")
        print(f"targetPath={target_path}")
        print(f"manifestDigest={manifest_digest}")
        print("action=skipped-existing")
        raise SystemExit(0)

action = "updated" if target_path.exists() else "wrote"

target_path.write_text(content)

print("BOOTSTRAP_WORKTREE_LANE:PASS")
print(f"branch={branch}")
print(f"laneId={lane_id}")
print(f"targetPath={target_path}")
print(f"manifestDigest={manifest_digest}")
print(f"action={action}")
PY
