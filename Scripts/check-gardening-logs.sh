#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from pathlib import Path

CHECKS = [
    (Path('Docs/Plan/logs/gardening-events.schema.json'), Path('Docs/Plan/logs/gardening-events.jsonl'), 'GARDENING_BASE'),
    (Path('Docs/Plan/logs/git-history-gardener.schema.json'), Path('Docs/Plan/logs/git-history-gardener.jsonl'), 'GIT_HISTORY_PROFILE'),
]


def parse_jsonl(jsonl_path: Path) -> tuple[list[dict], list[str]]:
    items: list[dict] = []
    errors: list[str] = []
    lines = [line for line in jsonl_path.read_text().splitlines() if line.strip()]
    if not lines:
        return items, [f'{jsonl_path} has no entries']
    for idx, line in enumerate(lines, start=1):
        try:
            obj = json.loads(line)
            if not isinstance(obj, dict):
                errors.append(f'{jsonl_path}: line {idx}: entry is not an object')
                continue
            items.append(obj)
        except Exception as exc:
            errors.append(f'{jsonl_path}: line {idx}: invalid JSON ({exc})')
    return items, errors


def validate_schema(schema_path: Path, entries: list[dict], label: str) -> list[str]:
    errors: list[str] = []
    if not schema_path.exists():
        return [f'{label}: missing schema {schema_path}']

    schema = json.loads(schema_path.read_text())
    required = set(schema.get('required', []))
    props = schema.get('properties', {})
    allowed = set(props.keys())
    additional = schema.get('additionalProperties', True)

    for idx, obj in enumerate(entries, start=1):
        prefix = f'{label}: line {idx}'

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
            enum = spec.get('enum')
            const = spec.get('const')
            pattern = spec.get('pattern')
            if enum is not None and value not in enum:
                errors.append(f'{prefix}: {key} value {value!r} not in enum {enum}')
            if const is not None and value != const:
                errors.append(f'{prefix}: {key} value {value!r} != const {const!r}')
            if pattern and isinstance(value, str):
                import re
                if not re.match(pattern, value):
                    errors.append(f'{prefix}: {key} value {value!r} does not match pattern {pattern!r}')

    return errors


def check_mirror_consistency(base_entries: list[dict], git_entries: list[dict]) -> list[str]:
    errors: list[str] = []
    approved_git_entries = [
        item for item in git_entries
        if item.get('sessionId') == 'git-history-gardener' and item.get('decision') == 'approved'
    ]
    base_git_entries = [
        item for item in base_entries
        if item.get('sessionId') == 'git-history-gardener'
    ]

    for entry in approved_git_entries:
        commit_range = entry.get('commitRange')
        candidate_commit = entry.get('candidateCommit')
        matched = False
        for base in base_git_entries:
            details = base.get('details') if isinstance(base.get('details'), dict) else {}
            if (
                base.get('date') == entry.get('date')
                and base.get('phaseLabel') == entry.get('phaseLabel')
                and base.get('decision') == entry.get('decision')
                and base.get('proposedAction') == entry.get('proposedAction')
                and details.get('commitRange') == commit_range
                and details.get('candidateCommit') == candidate_commit
            ):
                matched = True
                break
        if not matched:
            errors.append(
                'MIRROR: missing base gardening-events mirror for '
                f"git-history approved entry {entry.get('entryId')} "
                f'({commit_range}, {candidate_commit})'
            )
    return errors


all_errors: list[str] = []
parsed: dict[str, list[dict]] = {}

for schema_path, jsonl_path, label in CHECKS:
    if not jsonl_path.exists():
        all_errors.append(f'{label}: missing jsonl {jsonl_path}')
        continue
    entries, parse_errors = parse_jsonl(jsonl_path)
    parsed[label] = entries
    all_errors.extend(f'{label}: {err}' for err in parse_errors)
    all_errors.extend(validate_schema(schema_path, entries, label))

if 'GARDENING_BASE' in parsed and 'GIT_HISTORY_PROFILE' in parsed:
    all_errors.extend(check_mirror_consistency(parsed['GARDENING_BASE'], parsed['GIT_HISTORY_PROFILE']))

if all_errors:
    print('GARDENING_LOGS_CHECK:FAIL')
    for err in all_errors:
        print(err)
    raise SystemExit(1)

print('GARDENING_LOGS_CHECK:PASS')
PY
