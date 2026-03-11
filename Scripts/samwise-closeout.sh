#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

dry_run="false"
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    dry_run="true"
    break
  fi
done

python3 - "$@" <<'PY'
import argparse
import json
import re
from datetime import date
from pathlib import Path

ROOT = Path.cwd()
PARTNER_LOG = ROOT / "Docs/PersonaKit/Development/logs/partner-context-events.jsonl"
PARTNER_SCHEMA = ROOT / "Docs/PersonaKit/Development/logs/partner-context-events.schema.json"
DIARY_LOG = ROOT / "Docs/PersonaKit/Development/logs/samwise-diary.jsonl"
DIARY_SCHEMA = ROOT / "Docs/PersonaKit/Development/logs/samwise-diary.schema.json"


def parse_jsonl(path: Path) -> list[dict]:
    entries: list[dict] = []
    for index, line in enumerate(path.read_text().splitlines(), start=1):
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


def next_entry_id(entries: list[dict], prefix: str) -> str:
    if not entries:
        return f"{prefix}-0001"

    latest = entries[-1].get("entryId")
    if not isinstance(latest, str) or not re.match(rf"^{prefix}-[0-9]{{4}}$", latest):
        raise SystemExit(f"Cannot derive next {prefix} id from last entryId {latest!r}")

    return f"{prefix}-{int(latest.split('-')[-1]) + 1:04d}"


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


def validate_monotonic_ids(entries: list[dict], prefix: str, label: str) -> None:
    previous = None
    seen: set[str] = set()

    for index, entry in enumerate(entries, start=1):
        entry_id = entry.get("entryId")
        if not isinstance(entry_id, str):
            continue
        if entry_id in seen:
            raise SystemExit(f"{label}: line {index}: duplicate entryId {entry_id!r}")
        seen.add(entry_id)

        match = re.match(rf"^{prefix}-([0-9]{{4}})$", entry_id)
        if not match:
            raise SystemExit(f"{label}: line {index}: invalid entryId {entry_id!r}")

        current = int(match.group(1))
        if previous is not None and current <= previous:
            raise SystemExit(f"{label}: line {index}: entryId {entry_id!r} is not strictly monotonic")
        previous = current


parser = argparse.ArgumentParser(
    description=(
        "Append one partner-context event plus one Samwise diary entry, then "
        "leave projection and verification to the shell wrapper."
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
args = parser.parse_args()

partner_entries = parse_jsonl(PARTNER_LOG)
diary_entries = parse_jsonl(DIARY_LOG)
partner_schema = json.loads(PARTNER_SCHEMA.read_text())
diary_schema = json.loads(DIARY_SCHEMA.read_text())

partner_entry = {
    "entryId": next_entry_id(partner_entries, "PCL"),
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
    "entryId": next_entry_id(diary_entries, "SWD"),
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

with PARTNER_LOG.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(partner_entry, separators=(",", ":")) + "\n")

with DIARY_LOG.open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(diary_entry, separators=(",", ":")) + "\n")

validate_monotonic_ids(parse_jsonl(PARTNER_LOG), "PCL", "PARTNER_CONTEXT")
validate_monotonic_ids(parse_jsonl(DIARY_LOG), "SWD", "SAMWISE_DIARY")

print(f"Appended {partner_entry['entryId']} to {PARTNER_LOG}")
print(f"Appended {diary_entry['entryId']} to {DIARY_LOG}")
PY

if [[ "$dry_run" == "true" ]]; then
  exit 0
fi

swift run personakit log-docs --root .personakit --write
swift run personakit validate --root .personakit
swift run personakit log-docs --root .personakit --check
./Scripts/check-operational-records.sh
./Scripts/check-gardening-logs.sh
