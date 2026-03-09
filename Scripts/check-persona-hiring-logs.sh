#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import re
from pathlib import Path

SCHEMA_PATH = Path('Docs/PersonaKit/Development/logs/persona-hiring-reviews.schema.json')
JSONL_PATH = Path('Docs/PersonaKit/Development/logs/persona-hiring-reviews.jsonl')


def parse_jsonl(path: Path):
    if not path.exists():
        return [], [f'missing jsonl {path}']

    items = []
    errors = []
    lines = [line for line in path.read_text().splitlines() if line.strip()]
    if not lines:
        return items, [f'{path} has no entries']

    for idx, line in enumerate(lines, start=1):
        try:
            obj = json.loads(line)
            if not isinstance(obj, dict):
                errors.append(f'line {idx}: entry is not an object')
                continue
            items.append(obj)
        except Exception as exc:
            errors.append(f'line {idx}: invalid JSON ({exc})')
    return items, errors


def validate_schema(schema: dict, entries: list[dict]):
    errors = []
    required = set(schema.get('required', []))
    props = schema.get('properties', {})
    allowed = set(props.keys())
    additional = schema.get('additionalProperties', True)

    for idx, obj in enumerate(entries, start=1):
        prefix = f'line {idx}'
        missing = sorted(required - set(obj.keys()))
        if missing:
            errors.append(f'{prefix}: missing required fields {missing}')

        if not additional:
            extra = sorted(set(obj.keys()) - allowed)
            if extra:
                errors.append(f'{prefix}: extra fields not in schema {extra}')

        for key, spec in props.items():
            if key not in obj:
                continue
            value = obj[key]
            if 'enum' in spec and value not in spec['enum']:
                errors.append(f'{prefix}: {key} value {value!r} not in enum {spec["enum"]}')
            if 'const' in spec and value != spec['const']:
                errors.append(f'{prefix}: {key} value {value!r} != const {spec["const"]!r}')
            pattern = spec.get('pattern')
            if pattern and isinstance(value, str) and not re.match(pattern, value):
                errors.append(f'{prefix}: {key} value {value!r} does not match pattern {pattern!r}')
            if isinstance(value, (int, float)):
                minimum = spec.get('minimum')
                maximum = spec.get('maximum')
                if minimum is not None and value < minimum:
                    errors.append(f'{prefix}: {key} value {value} < minimum {minimum}')
                if maximum is not None and value > maximum:
                    errors.append(f'{prefix}: {key} value {value} > maximum {maximum}')

    return errors


def validate_paths(entries: list[dict]):
    errors = []
    seen_entry_ids = set()
    for idx, obj in enumerate(entries, start=1):
        prefix = f'line {idx}'
        entry_id = obj.get('entryId')
        if entry_id in seen_entry_ids:
            errors.append(f'{prefix}: duplicate entryId {entry_id!r}')
        seen_entry_ids.add(entry_id)

        report_path = obj.get('reportPath')
        if isinstance(report_path, str) and report_path:
            if not Path(report_path).exists():
                errors.append(f'{prefix}: reportPath does not exist: {report_path}')
    return errors


all_errors = []

if not SCHEMA_PATH.exists():
    all_errors.append(f'missing schema {SCHEMA_PATH}')
else:
    schema = json.loads(SCHEMA_PATH.read_text())
    entries, parse_errors = parse_jsonl(JSONL_PATH)
    all_errors.extend(parse_errors)
    if entries:
        all_errors.extend(validate_schema(schema, entries))
        all_errors.extend(validate_paths(entries))

if all_errors:
    print('PERSONA_HIRING_LOGS_CHECK:FAIL')
    for err in all_errors:
        print(err)
    raise SystemExit(1)

print('PERSONA_HIRING_LOGS_CHECK:PASS')
PY
