#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import re
from pathlib import Path

CHECKS = [
    (
        Path("Docs/PersonaKit/Development/logs/worktree-squad-loops.schema.json"),
        Path("Docs/PersonaKit/Development/logs/worktree-squad-loops.jsonl"),
        "WORKTREE_SQUAD_LOOP",
    ),
    (
        Path("Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.schema.json"),
        Path("Docs/PersonaKit/Development/logs/worktree-squad-retrospectives.jsonl"),
        "WORKTREE_SQUAD_RETRO",
    ),
]

STRICT_RETRO_DATE = "2026-03-09"


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
            if isinstance(value, (int, float)):
                minimum = spec.get("minimum")
                maximum = spec.get("maximum")
                if minimum is not None and value < minimum:
                    errors.append(f"{prefix}: {key} value {value} < minimum {minimum}")
                if maximum is not None and value > maximum:
                    errors.append(f"{prefix}: {key} value {value} > maximum {maximum}")

    return errors


def check_entry_ids(entries: list[dict], label: str):
    errors = []
    seen = set()
    previous = None
    for idx, entry in enumerate(entries, start=1):
        entry_id = entry.get("entryId")
        if not isinstance(entry_id, str):
            continue
        if entry_id in seen:
            errors.append(f"{label}: line {idx}: duplicate entryId {entry_id!r}")
        seen.add(entry_id)
        suffix = entry_id.rsplit("-", maxsplit=1)[-1]
        if suffix.isdigit():
            value = int(suffix)
            if previous is not None and value <= previous:
                errors.append(
                    f"{label}: line {idx}: entryId {entry_id!r} is not strictly monotonic"
                )
            previous = value
    return errors


def check_report_paths(entries: list[dict], label: str):
    errors = []
    for idx, entry in enumerate(entries, start=1):
        report_path = entry.get("reportPath")
        if isinstance(report_path, str) and report_path:
            if not Path(report_path).exists():
                errors.append(
                    f"{label}: line {idx}: reportPath does not exist: {report_path}"
                )
    return errors


def check_path_list(entries: list[dict], key: str, label: str):
    errors = []
    for idx, entry in enumerate(entries, start=1):
        values = entry.get(key)
        if not isinstance(values, list):
            continue
        for value in values:
            if isinstance(value, str) and value and not Path(value).exists():
                errors.append(
                    f"{label}: line {idx}: {key} path does not exist: {value}"
                )
    return errors


def check_retro_shapes(entries: list[dict], label: str):
    errors = []
    starfish_keys = {"keepDoing", "lessOf", "moreOf", "stopDoing", "startDoing"}
    legacy_keys = {"whatWentWell", "whatDidNot", "openQuestions", "improvements"}

    for idx, entry in enumerate(entries, start=1):
        prefix = f"{label}: line {idx}"
        has_starfish = starfish_keys.issubset(entry.keys())
        has_legacy = legacy_keys.issubset(entry.keys())

        if not has_starfish and not has_legacy:
            errors.append(
                f"{prefix}: retrospective entry must include either Starfish fields "
                f"{sorted(starfish_keys)} or legacy fields {sorted(legacy_keys)}"
            )

    return errors


def check_strict_retro_fields(entries: list[dict], label: str):
    errors = []
    strict_fields = [
        "retrospectiveMethod",
        "declaredRoles",
        "actualParticipants",
        "participantEvidencePaths",
        "subagentCount",
        "featureConfidence",
        "productConfidence",
        "processConfidence",
    ]

    for idx, entry in enumerate(entries, start=1):
        prefix = f"{label}: line {idx}"

        if entry.get("entryType") != "retrospective":
            continue
        if entry.get("sessionId") != "worktree-squad-retrospective":
            continue

        date = entry.get("date")
        if not isinstance(date, str) or date < STRICT_RETRO_DATE:
            continue

        missing = [field for field in strict_fields if field not in entry]
        if missing:
            errors.append(
                f"{prefix}: post-{STRICT_RETRO_DATE} retrospective missing strict fields {missing}"
            )
            continue

        declared_roles = entry.get("declaredRoles")
        actual_participants = entry.get("actualParticipants")
        participant_evidence = entry.get("participantEvidencePaths")
        retrospective_method = entry.get("retrospectiveMethod")
        subagent_count = entry.get("subagentCount")

        if not isinstance(declared_roles, list) or not declared_roles:
            errors.append(f"{prefix}: declaredRoles must be a non-empty array")
        if not isinstance(actual_participants, list) or not actual_participants:
            errors.append(f"{prefix}: actualParticipants must be a non-empty array")
        if not isinstance(participant_evidence, list) or not participant_evidence:
            errors.append(
                f"{prefix}: participantEvidencePaths must be a non-empty array"
            )
        if isinstance(subagent_count, int) and subagent_count < 0:
            errors.append(f"{prefix}: subagentCount must be >= 0")

        if retrospective_method in {"fan-out", "hybrid"}:
            participant_count = (
                len(actual_participants) if isinstance(actual_participants, list) else 0
            )
            if participant_count < 2:
                errors.append(
                    f"{prefix}: {retrospective_method} retrospectives require at least "
                    "two actualParticipants"
                )

    return errors


all_errors = []
for schema_path, jsonl_path, label in CHECKS:
    if not schema_path.exists():
        all_errors.append(f"{label}: missing schema {schema_path}")
        continue

    schema = json.loads(schema_path.read_text())
    entries, parse_errors = parse_jsonl(jsonl_path)
    all_errors.extend(parse_errors)
    if not entries:
        continue
    all_errors.extend(validate_schema(schema, entries, label))
    all_errors.extend(check_entry_ids(entries, label))
    all_errors.extend(check_report_paths(entries, label))
    if label == "WORKTREE_SQUAD_RETRO":
        all_errors.extend(check_retro_shapes(entries, label))
        all_errors.extend(check_path_list(entries, "participantEvidencePaths", label))
        all_errors.extend(check_strict_retro_fields(entries, label))

if all_errors:
    print("WORKTREE_SQUAD_LOGS_CHECK:FAIL")
    for err in all_errors:
        print(err)
    raise SystemExit(1)

print("WORKTREE_SQUAD_LOGS_CHECK:PASS")
PY
