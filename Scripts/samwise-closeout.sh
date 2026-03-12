#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

state_file="$(mktemp "${TMPDIR:-/tmp}/samwise-closeout.XXXXXX.json")"
cleanup_state_file() {
  rm -f "$state_file"
}
trap cleanup_state_file EXIT

dry_run="false"
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    dry_run="true"
    break
  fi
done

python3 - "$state_file" "$@" <<'PY'
import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path.cwd()
PARTNER_LOG = ROOT / "Docs/PersonaKit/Development/logs/partner-context-events.jsonl"
PARTNER_SCHEMA = ROOT / "Docs/PersonaKit/Development/logs/partner-context-events.schema.json"
PARTNER_PROJECTION = ROOT / "Docs/PersonaKit/Development/partner-context-log.md"
DIARY_LOG = ROOT / "Docs/PersonaKit/Development/logs/samwise-diary.jsonl"
DIARY_SCHEMA = ROOT / "Docs/PersonaKit/Development/logs/samwise-diary.schema.json"
STATE_PATH = Path(sys.argv[1])


def parse_jsonl(path: Path) -> list[dict]:
    entries: list[dict] = []
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except Exception as exc:  # pragma: no cover - script path
            raise SystemExit(f"{path}: line {index}: invalid JSON ({exc})")
        if not isinstance(value, dict):
            raise SystemExit(f"{path}: line {index}: entry is not an object")
        entries.append(value)
    return entries


def validate_monotonic_ids(entries: list[dict], prefix: str, label: str) -> None:
    previous = None
    seen: set[str] = set()

    for index, entry in enumerate(entries, start=1):
        entry_id = entry.get("entryId")
        if not isinstance(entry_id, str):
            raise SystemExit(f"{label}: line {index}: missing string entryId")
        match = re.match(rf"^{prefix}-([0-9]{{4}})$", entry_id)
        if not match:
            raise SystemExit(f"{label}: line {index}: invalid entryId {entry_id!r}")
        if entry_id in seen:
            raise SystemExit(f"{label}: line {index}: duplicate entryId {entry_id!r}")
        seen.add(entry_id)

        current = int(match.group(1))
        if previous is not None and current <= previous:
            raise SystemExit(f"{label}: line {index}: entryId {entry_id!r} is not strictly monotonic")
        previous = current


def next_entry_id(entries: list[dict], prefix: str, label: str) -> str:
    if not entries:
        return f"{prefix}-0001"

    suffixes: list[int] = []
    for index, entry in enumerate(entries, start=1):
        entry_id = entry.get("entryId")
        if not isinstance(entry_id, str):
            raise SystemExit(f"{label}: line {index}: missing string entryId")
        match = re.match(rf"^{prefix}-([0-9]{{4}})$", entry_id)
        if not match:
            raise SystemExit(f"{label}: line {index}: invalid entryId {entry_id!r}")
        suffixes.append(int(match.group(1)))

    return f"{prefix}-{max(suffixes) + 1:04d}"


def validate_entry(entry: dict, schema: dict, label: str) -> None:
    required = set(schema.get("required", []))
    missing = sorted(required - set(entry.keys()))
    if missing:
        raise SystemExit(f"{label}: missing required fields {missing}")

    properties = schema.get("properties", {})
    if not schema.get("additionalProperties", True):
        extras = sorted(set(entry.keys()) - set(properties.keys()))
        if extras:
            raise SystemExit(f"{label}: extra fields not in schema {extras}")

    for key, spec in properties.items():
        if key not in entry:
            continue
        value = entry[key]
        if "const" in spec and value != spec["const"]:
            raise SystemExit(f"{label}: {key} value {value!r} != const {spec['const']!r}")
        pattern = spec.get("pattern")
        if pattern and isinstance(value, str) and not re.match(pattern, value):
            raise SystemExit(f"{label}: {key} value {value!r} does not match pattern {pattern!r}")
        min_length = spec.get("minLength")
        if min_length is not None and isinstance(value, str) and len(value) < min_length:
            raise SystemExit(f"{label}: {key} shorter than minLength {min_length}")


def append_jsonl_entry(path: Path, entry: dict) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, separators=(",", ":")) + "\n")


def rollback_last_entry(path: Path, expected_entry_id: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise SystemExit(f"Cannot rollback {path}: file has no entries")

    last_entry = json.loads(lines[-1])
    if last_entry.get("entryId") != expected_entry_id:
        raise SystemExit(
            f"Refusing rollback for {path}: last entryId {last_entry.get('entryId')!r} "
            f"does not match expected {expected_entry_id!r}"
        )

    remaining_lines = lines[:-1]
    new_contents = "\n".join(remaining_lines)
    if remaining_lines:
        new_contents += "\n"
    path.write_text(new_contents, encoding="utf-8")


parser = argparse.ArgumentParser(
    description=(
        "Append one partner-context event plus one Samwise diary entry, then "
        "run the existing projection and verification commands."
    )
)
parser.add_argument("--date", default=date.today().isoformat())
parser.add_argument("--partner-session-id", default="samwise-partner-sync")
parser.add_argument("--partner-summary", required=True)
parser.add_argument("--partner-implications", required=True)
parser.add_argument("--partner-next-action", required=True)
parser.add_argument("--partner-verification", required=True)
parser.add_argument("--partner-affected-id", action="append", default=[])
parser.add_argument("--partner-details-json")
parser.add_argument("--diary-summary", required=True)
parser.add_argument("--diary-what-shipped", action="append", default=[])
parser.add_argument("--diary-what-learned", action="append", default=[])
parser.add_argument("--diary-improvement", action="append", default=[])
parser.add_argument("--diary-next-goal", action="append", default=[])
parser.add_argument("--reviewer", default="AJ")
parser.add_argument("--dry-run", action="store_true")
args = parser.parse_args(sys.argv[2:])

partner_entries = parse_jsonl(PARTNER_LOG)
diary_entries = parse_jsonl(DIARY_LOG)
partner_schema = json.loads(PARTNER_SCHEMA.read_text(encoding="utf-8"))
diary_schema = json.loads(DIARY_SCHEMA.read_text(encoding="utf-8"))

validate_monotonic_ids(partner_entries, "PCL", "PARTNER_CONTEXT")
validate_monotonic_ids(diary_entries, "SWD", "SAMWISE_DIARY")

partner_entry = {
    "entryId": next_entry_id(partner_entries, "PCL", "PARTNER_CONTEXT"),
    "date": args.date,
    "sessionId": args.partner_session_id,
    "summary": args.partner_summary,
    "implications": args.partner_implications,
    "affectedIds": args.partner_affected_id,
    "nextAction": args.partner_next_action,
    "verification": args.partner_verification,
}
if args.partner_details_json:
    partner_entry["details"] = json.loads(args.partner_details_json)

diary_entry = {
    "entryId": next_entry_id(diary_entries, "SWD", "SAMWISE_DIARY"),
    "date": args.date,
    "sessionId": "samwise-daily-closeout",
    "summary": args.diary_summary,
    "whatShipped": args.diary_what_shipped,
    "whatLearned": args.diary_what_learned,
    "improvements": args.diary_improvement,
    "nextGoals": args.diary_next_goal,
    "reviewer": args.reviewer,
}

validate_entry(partner_entry, partner_schema, "PARTNER_CONTEXT")
validate_entry(diary_entry, diary_schema, "SAMWISE_DIARY")

if args.dry_run:
    print(json.dumps({"partnerEntry": partner_entry, "diaryEntry": diary_entry}, indent=2))
    raise SystemExit(0)

partner_projection_snapshot = {
    "path": str(PARTNER_PROJECTION),
    "exists": PARTNER_PROJECTION.exists(),
    "content": PARTNER_PROJECTION.read_text(encoding="utf-8") if PARTNER_PROJECTION.exists() else None,
}

STATE_PATH.write_text(
    json.dumps(
        {
            "partnerLogPath": str(PARTNER_LOG),
            "partnerEntryId": partner_entry["entryId"],
            "diaryLogPath": str(DIARY_LOG),
            "diaryEntryId": diary_entry["entryId"],
            "partnerProjection": partner_projection_snapshot,
        },
        separators=(",", ":"),
    ),
    encoding="utf-8",
)

partner_appended = False
diary_appended = False

try:
    append_jsonl_entry(PARTNER_LOG, partner_entry)
    partner_appended = True
    append_jsonl_entry(DIARY_LOG, diary_entry)
    diary_appended = True
    validate_monotonic_ids(parse_jsonl(PARTNER_LOG), "PCL", "PARTNER_CONTEXT")
    validate_monotonic_ids(parse_jsonl(DIARY_LOG), "SWD", "SAMWISE_DIARY")
except BaseException:
    if diary_appended:
        rollback_last_entry(DIARY_LOG, diary_entry["entryId"])
    if partner_appended:
        rollback_last_entry(PARTNER_LOG, partner_entry["entryId"])
    raise

print(f"Appended {partner_entry['entryId']} to {PARTNER_LOG}")
print(f"Appended {diary_entry['entryId']} to {DIARY_LOG}")
PY

if [[ "$dry_run" == "true" ]]; then
  exit 0
fi

rollback_closeout() {
  python3 - "$state_file" <<'PY'
import json
import sys
from pathlib import Path


def rollback_last_entry(path: Path, expected_entry_id: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines:
        raise SystemExit(f"Cannot rollback {path}: file has no entries")

    last_entry = json.loads(lines[-1])
    if last_entry.get("entryId") != expected_entry_id:
        raise SystemExit(
            f"Refusing rollback for {path}: last entryId {last_entry.get('entryId')!r} "
            f"does not match expected {expected_entry_id!r}"
        )

    remaining_lines = lines[:-1]
    new_contents = "\n".join(remaining_lines)
    if remaining_lines:
        new_contents += "\n"
    path.write_text(new_contents, encoding="utf-8")


def restore_projection(snapshot: dict) -> None:
    path = Path(snapshot["path"])
    if snapshot["exists"]:
        content = snapshot["content"]
        if not isinstance(content, str):
            raise SystemExit(f"Cannot restore {path}: missing snapshot content")
        path.write_text(content, encoding="utf-8")
    elif path.exists():
        path.unlink()


state_path = Path(sys.argv[1])
state = json.loads(state_path.read_text(encoding="utf-8"))
rollback_last_entry(Path(state["diaryLogPath"]), state["diaryEntryId"])
rollback_last_entry(Path(state["partnerLogPath"]), state["partnerEntryId"])
restore_projection(state["partnerProjection"])
PY
}

run_post_append_checks() {
  swift run personakit log-docs --root .personakit --write
  swift run personakit validate --root .personakit
  swift run personakit log-docs --root .personakit --check
  ./Scripts/check-operational-records.sh
  ./Scripts/check-gardening-logs.sh
}

if ! run_post_append_checks; then
  rollback_closeout
  exit 1
fi
