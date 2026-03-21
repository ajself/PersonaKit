#!/usr/bin/env bash
set -euo pipefail

manifest_path="Docs/PersonaKit/Development/worktree-lane-approvals.json"
branch=""
worktree_path=""
dry_run="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest_path="$2"
      shift 2
      ;;
    --branch)
      branch="$2"
      shift 2
      ;;
    --path)
      worktree_path="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="1"
      shift 1
      ;;
    *)
      echo "Usage: $0 --branch branch --path /absolute/path [--manifest path] [--dry-run]" >&2
      exit 64
      ;;
  esac
done

export WORKTREE_LANE_MANIFEST="$manifest_path"
export WORKTREE_LANE_BRANCH="$branch"
export WORKTREE_LANE_PATH="$worktree_path"
export WORKTREE_LANE_DRY_RUN="$dry_run"

python3 - <<'PY'
import json
import os
import shlex
import subprocess
from pathlib import Path


def git_ref_exists(ref: str) -> bool:
    return (
        subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", ref],
            check=False,
        ).returncode
        == 0
    )


manifest_path = Path(os.environ["WORKTREE_LANE_MANIFEST"])
branch = os.environ.get("WORKTREE_LANE_BRANCH", "").strip()
worktree_path_raw = os.environ.get("WORKTREE_LANE_PATH", "").strip()
dry_run = os.environ.get("WORKTREE_LANE_DRY_RUN", "0") == "1"

if not branch:
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print("missing required --branch value")
    raise SystemExit(1)

if not worktree_path_raw:
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print("missing required --path value")
    raise SystemExit(1)

worktree_path = Path(worktree_path_raw)
if worktree_path.exists():
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print(f"target path already exists: {worktree_path}")
    raise SystemExit(1)

if not manifest_path.exists():
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print(f"missing manifest {manifest_path}")
    raise SystemExit(1)

data = json.loads(manifest_path.read_text())
lanes = data.get("lanes")

if not isinstance(lanes, list):
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print("manifest field 'lanes' must be a list")
    raise SystemExit(1)

matches = [lane for lane in lanes if isinstance(lane, dict) and lane.get("branch") == branch]

if not matches:
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print(f"branch {branch!r} is not recorded in {manifest_path}")
    raise SystemExit(1)

if len(matches) > 1:
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print(f"branch {branch!r} has multiple lane entries in {manifest_path}")
    raise SystemExit(1)

lane = matches[0]
lane_id = lane.get("laneId")
status = lane.get("status")
if status == "protected":
    print("MATERIALIZE_WORKTREE_LANE:FAIL")
    print(f"branch {branch!r} is protected and must not be materialized as an execution lane")
    raise SystemExit(1)

source_branch = lane.get("sourceBranch")
start_point = lane.get("startPoint")
lane_note_path = lane.get("laneNotePath")

local_branch_ref = f"refs/heads/{branch}"
remote_branch_ref = f"refs/remotes/origin/{branch}"

if git_ref_exists(local_branch_ref):
    create_cmd = ["git", "worktree", "add", str(worktree_path), branch]
    creation_source = branch
    creation_action = "attach-existing-local-branch"
elif git_ref_exists(remote_branch_ref):
    create_cmd = ["git", "worktree", "add", "-b", branch, str(worktree_path), remote_branch_ref]
    creation_source = remote_branch_ref
    creation_action = "create-from-remote-branch"
else:
    creation_source = start_point or source_branch
    if not creation_source:
        print("MATERIALIZE_WORKTREE_LANE:FAIL")
        print(
            f"lane {lane_id!r} needs sourceBranch or startPoint before a new worktree can be created"
        )
        raise SystemExit(1)
    create_cmd = ["git", "worktree", "add", "-b", branch, str(worktree_path), creation_source]
    creation_action = "create-from-lane-contract"

bootstrap_cmd = None
bootstrap_target = None
if isinstance(lane_note_path, str) and lane_note_path:
    bootstrap_target = worktree_path / lane_note_path
    bootstrap_cmd = [
        "Scripts/bootstrap-worktree-lane.sh",
        "--branch",
        branch,
        "--output",
        str(bootstrap_target),
    ]

if dry_run:
    print("MATERIALIZE_WORKTREE_LANE:PASS")
    print("mode=dry-run")
    print(f"branch={branch}")
    print(f"laneId={lane_id}")
    print(f"status={status}")
    print(f"targetPath={worktree_path}")
    print(f"creationAction={creation_action}")
    print(f"creationSource={creation_source}")
    print(f"createCommand={' '.join(shlex.quote(part) for part in create_cmd)}")
    if bootstrap_cmd is not None:
        print(f"bootstrapTarget={bootstrap_target}")
        print(
            f"bootstrapCommand={' '.join(shlex.quote(part) for part in bootstrap_cmd)}"
        )
    raise SystemExit(0)

subprocess.run(create_cmd, check=True)

if bootstrap_cmd is not None:
    subprocess.run(bootstrap_cmd, check=True)

subprocess.run(["bash", "Scripts/check-worktree-lane.sh"], check=True, cwd=worktree_path)

print("MATERIALIZE_WORKTREE_LANE:PASS")
print("mode=execute")
print(f"branch={branch}")
print(f"laneId={lane_id}")
print(f"status={status}")
print(f"targetPath={worktree_path}")
print(f"creationAction={creation_action}")
print(f"creationSource={creation_source}")
if bootstrap_target is not None:
    print(f"bootstrapTarget={bootstrap_target}")
print("authorityPreflight=passed")
PY
