#!/usr/bin/env bash
set -euo pipefail

manifest_path="Docs/current-state.json"

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

export CURRENT_STATE_MANIFEST="$manifest_path"

python3 - <<'PY'
import json
import os
import re
from pathlib import Path

manifest_path = Path(os.environ["CURRENT_STATE_MANIFEST"])

if not manifest_path.exists():
    print("CURRENT_STATE_CHECK:FAIL")
    print(f"missing manifest {manifest_path}")
    raise SystemExit(1)

data = json.loads(manifest_path.read_text())
errors: list[str] = []

if data.get("version") != 1:
    errors.append(f"manifest version must be 1, found {data.get('version')!r}")

authority_doc_value = data.get("authorityDoc")
if not isinstance(authority_doc_value, str) or not authority_doc_value:
    errors.append("authorityDoc must be a non-empty string")
    authority_doc_path = None
else:
    authority_doc_path = Path(authority_doc_value)
    if not authority_doc_path.exists():
        errors.append(f"authorityDoc does not exist: {authority_doc_value!r}")

allowed_current_status = {"active", "ready-for-review", "blocked"}
allowed_next_status = {"staged"}
allowed_non_active_groups = {"blocked", "parked", "historical"}
seen_ids: set[str] = set()


def expect_non_empty_string(prefix: str, obj: dict, key: str):
    value = obj.get(key)
    if not isinstance(value, str) or not value:
        errors.append(f"{prefix} field {key!r} must be a non-empty string")
        return None
    return value


current = data.get("current")
if not isinstance(current, dict):
    errors.append("current must be an object")
    current = {}

current_id = expect_non_empty_string("current", current, "id")
current_packet_id = expect_non_empty_string("current", current, "packetId")
current_status = expect_non_empty_string("current", current, "status")

for key in ["program", "workspace", "milestoneId", "title", "ownerPersona"]:
    expect_non_empty_string("current", current, key)

if current_status is not None and current_status not in allowed_current_status:
    errors.append(
        f"current status must be one of {sorted(allowed_current_status)}, found {current_status!r}"
    )

if current_id is not None:
    seen_ids.add(current_id)

source_refs = current.get("sourceRefs")
if not isinstance(source_refs, list) or not source_refs:
    errors.append("current field 'sourceRefs' must be a non-empty list")
else:
    for idx, ref in enumerate(source_refs, start=1):
        if not isinstance(ref, str) or not ref:
            errors.append(f"current sourceRefs[{idx}] must be a non-empty string")
        elif not Path(ref).exists():
            errors.append(f"current sourceRefs[{idx}] does not exist: {ref!r}")

next_item = data.get("next")
if next_item is not None:
    if not isinstance(next_item, dict):
        errors.append("next must be null or an object")
    else:
        next_id = expect_non_empty_string("next", next_item, "id")
        next_status = expect_non_empty_string("next", next_item, "status")
        if next_status is not None and next_status not in allowed_next_status:
            errors.append(
                f"next status must be one of {sorted(allowed_next_status)}, found {next_status!r}"
            )
        for key in ["program", "workspace", "milestoneId", "packetId", "title", "ownerPersona"]:
            expect_non_empty_string("next", next_item, key)
        next_refs = next_item.get("sourceRefs")
        if not isinstance(next_refs, list) or not next_refs:
            errors.append("next field 'sourceRefs' must be a non-empty list")
        else:
            for idx, ref in enumerate(next_refs, start=1):
                if not isinstance(ref, str) or not ref:
                    errors.append(f"next sourceRefs[{idx}] must be a non-empty string")
                elif not Path(ref).exists():
                    errors.append(f"next sourceRefs[{idx}] does not exist: {ref!r}")
        if next_id is not None:
            if next_id in seen_ids:
                errors.append(f"duplicate id across current/next/nonActive: {next_id!r}")
            seen_ids.add(next_id)

non_active = data.get("nonActive")
if not isinstance(non_active, dict):
    errors.append("nonActive must be an object")
    non_active = {}

for group in allowed_non_active_groups:
    entries = non_active.get(group)
    if not isinstance(entries, list):
        errors.append(f"nonActive field {group!r} must be a list")
        continue
    for idx, entry in enumerate(entries, start=1):
        prefix = f"nonActive.{group}[{idx}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entry_id = expect_non_empty_string(prefix, entry, "id")
        expect_non_empty_string(prefix, entry, "title")
        if entry_id is not None:
            if entry_id in seen_ids:
                errors.append(f"duplicate id across current/next/nonActive: {entry_id!r}")
            seen_ids.add(entry_id)

if authority_doc_path is not None and authority_doc_path.exists():
    doc_text = authority_doc_path.read_text()

    packet_match = re.search(r"^- Packet Id: `([^`]+)`$", doc_text, re.MULTILINE)
    status_match = re.search(r"^- Status: `([^`]+)`$", doc_text, re.MULTILINE)
    next_none_match = re.search(r"^## Next Up\s+?- None staged\.$", doc_text, re.MULTILINE | re.DOTALL)

    if current_packet_id is not None:
        if packet_match is None:
            errors.append("authority doc is missing current packet id line")
        elif packet_match.group(1) != current_packet_id:
            errors.append(
                "authority doc packet id does not match manifest "
                f"({packet_match.group(1)!r} != {current_packet_id!r})"
            )

    if current_status is not None:
        if status_match is None:
            errors.append("authority doc is missing current status line")
        elif status_match.group(1) != current_status:
            errors.append(
                "authority doc current status does not match manifest "
                f"({status_match.group(1)!r} != {current_status!r})"
            )

    if next_item is None:
        if next_none_match is None:
            errors.append("authority doc must state '- None staged.' when next is null")

if errors:
    print("CURRENT_STATE_CHECK:FAIL")
    for error in errors:
        print(error)
    raise SystemExit(1)

print("CURRENT_STATE_CHECK:PASS")
print(f"manifest={manifest_path}")
print(f"current={current_id}")
print(f"status={current_status}")
PY
