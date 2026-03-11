#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import re
from pathlib import Path

CHECKS = [
    (
        Path("Docs/PersonaKit/Development/logs/partner-context-events.schema.json"),
        Path("Docs/PersonaKit/Development/logs/partner-context-events.jsonl"),
        "PARTNER_CONTEXT",
    ),
    (
        Path("Docs/PersonaKit/Development/logs/partner-handoffs.schema.json"),
        Path("Docs/PersonaKit/Development/logs/partner-handoffs.jsonl"),
        "PARTNER_HANDOFFS",
    ),
    (
        Path("Docs/PersonaKit/Development/logs/git-history-gardener-proposals.schema.json"),
        Path("Docs/PersonaKit/Development/logs/git-history-gardener-proposals.jsonl"),
        "GIT_HISTORY_PROPOSALS",
    ),
]


def parse_jsonl(path: Path):
    if not path.exists():
        return [], [f"missing jsonl {path}"]

    lines = [line for line in path.read_text().splitlines() if line.strip()]
    if not lines:
        return [], [f"{path} has no entries"]

    entries = []
    errors = []
    for idx, line in enumerate(lines, start=1):
        try:
            obj = json.loads(line)
        except Exception as exc:
            errors.append(f"{path}: line {idx}: invalid JSON ({exc})")
            continue
        if not isinstance(obj, dict):
            errors.append(f"{path}: line {idx}: entry is not an object")
            continue
        entries.append(obj)
    return entries, errors


def validate_schema(schema: dict, entries: list[dict], label: str):
    errors = []
    required = set(schema.get("required", []))
    props = schema.get("properties", {})
    allowed = set(props.keys())
    additional = schema.get("additionalProperties", True)

    for idx, obj in enumerate(entries, start=1):
        prefix = f"{label}: line {idx}"
        missing = sorted(required - set(obj.keys()))
        if missing:
            errors.append(f"{prefix}: missing required fields {missing}")

        if not additional:
            extras = sorted(set(obj.keys()) - allowed)
            if extras:
                errors.append(f"{prefix}: extra fields not in schema {extras}")

        for key, spec in props.items():
            if key not in obj:
                continue
            value = obj[key]
            if "enum" in spec and value not in spec["enum"]:
                errors.append(f"{prefix}: {key} value {value!r} not in enum {spec['enum']}")
            if "const" in spec and value != spec["const"]:
                errors.append(f"{prefix}: {key} value {value!r} != const {spec['const']!r}")
            pattern = spec.get("pattern")
            if pattern and isinstance(value, str) and not re.match(pattern, value):
                errors.append(f"{prefix}: {key} value {value!r} does not match pattern {pattern!r}")
    return errors


def check_monotonic_entry_ids(entries: list[dict], label: str):
    errors = []
    previous = None
    seen = set()

    for idx, entry in enumerate(entries, start=1):
        entry_id = entry.get("entryId")
        if not isinstance(entry_id, str):
            continue

        if entry_id in seen:
            errors.append(f"{label}: line {idx}: duplicate entryId {entry_id!r}")
        seen.add(entry_id)

        suffix = entry_id.rsplit("-", maxsplit=1)[-1]
        if suffix.isdigit():
          current = int(suffix)
          if previous is not None and current <= previous:
              errors.append(
                  f"{label}: line {idx}: entryId {entry_id!r} is not strictly monotonic"
              )
          previous = current

    return errors


def main():
    errors = []

    for schema_path, jsonl_path, label in CHECKS:
        if not schema_path.exists():
            errors.append(f"{label}: missing schema {schema_path}")
            continue

        schema = json.loads(schema_path.read_text())
        entries, parse_errors = parse_jsonl(jsonl_path)
        errors.extend(parse_errors)
        if parse_errors:
            continue

        errors.extend(validate_schema(schema, entries, label))
        errors.extend(check_monotonic_entry_ids(entries, label))

    if errors:
        print("OPERATIONAL_RECORDS_CHECK:FAIL")
        for error in errors:
            print(error)
        raise SystemExit(1)

    print("OPERATIONAL_RECORDS_CHECK:PASS")


main()
PY
