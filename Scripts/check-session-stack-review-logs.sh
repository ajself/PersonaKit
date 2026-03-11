#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import re
from pathlib import Path

SCHEMA_PATH = Path("Docs/PersonaKit/Development/logs/session-stack-reviews.schema.json")
JSONL_PATH = Path("Docs/PersonaKit/Development/logs/session-stack-reviews.jsonl")
SESSIONS_DIR = Path(".personakit/Sessions")


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


def validate_schema(schema: dict, entries: list[dict]):
    errors = []
    required = set(schema.get("required", []))
    props = schema.get("properties", {})
    allowed = set(props.keys())
    additional = schema.get("additionalProperties", True)

    for idx, obj in enumerate(entries, start=1):
        prefix = f"line {idx}"
        missing = sorted(required - set(obj.keys()))
        if missing:
            errors.append(f"{prefix}: missing required fields {missing}")

        if not additional:
            extra = sorted(set(obj.keys()) - allowed)
            if extra:
                errors.append(f"{prefix}: extra fields not in schema {extra}")

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
            if isinstance(value, (int, float)):
                minimum = spec.get("minimum")
                maximum = spec.get("maximum")
                if minimum is not None and value < minimum:
                    errors.append(f"{prefix}: {key} value {value} < minimum {minimum}")
                if maximum is not None and value > maximum:
                    errors.append(f"{prefix}: {key} value {value} > maximum {maximum}")

    return errors


def check_entry_ids(entries: list[dict]):
    errors = []
    seen = set()
    previous = None
    for idx, entry in enumerate(entries, start=1):
        entry_id = entry.get("entryId")
        if not isinstance(entry_id, str):
            continue
        if entry_id in seen:
            errors.append(f"line {idx}: duplicate entryId {entry_id!r}")
        seen.add(entry_id)
        suffix = entry_id.rsplit("-", maxsplit=1)[-1]
        if suffix.isdigit():
            value = int(suffix)
            if previous is not None and value <= previous:
                errors.append(f"line {idx}: entryId {entry_id!r} is not strictly monotonic")
            previous = value
    return errors


def check_cross_refs(entries: list[dict]):
    errors = []
    for idx, entry in enumerate(entries, start=1):
        report_path = entry.get("reportPath")
        if isinstance(report_path, str) and report_path:
            if not Path(report_path).exists():
                errors.append(f"line {idx}: reportPath does not exist: {report_path}")

        target_session_id = entry.get("targetSessionId")
        if isinstance(target_session_id, str) and target_session_id:
            session_path = SESSIONS_DIR / f"{target_session_id}.session.json"
            if not session_path.exists():
                errors.append(
                    f"line {idx}: targetSessionId does not resolve to a session file: {target_session_id}"
                )

        verdict = entry.get("verdict")
        current_confidence = entry.get("currentOverallConfidence")
        projected_confidence = entry.get("projectedOverallConfidence")
        mcp_status = entry.get("mcpStatus")

        if verdict == "blocked":
            if mcp_status == "pass":
                errors.append(f"line {idx}: blocked verdict cannot use mcpStatus 'pass'")
        else:
            if current_confidence is None or projected_confidence is None:
                errors.append(
                    f"line {idx}: non-blocked review must include current/projected confidence"
                )
    return errors


all_errors = []

if not SCHEMA_PATH.exists():
    all_errors.append(f"missing schema {SCHEMA_PATH}")
else:
    schema = json.loads(SCHEMA_PATH.read_text())
    entries, parse_errors = parse_jsonl(JSONL_PATH)
    all_errors.extend(parse_errors)
    if entries:
        all_errors.extend(validate_schema(schema, entries))
        all_errors.extend(check_entry_ids(entries))
        all_errors.extend(check_cross_refs(entries))

if all_errors:
    print("SESSION_STACK_REVIEW_LOGS_CHECK:FAIL")
    for err in all_errors:
        print(err)
    raise SystemExit(1)

print("SESSION_STACK_REVIEW_LOGS_CHECK:PASS")
PY
