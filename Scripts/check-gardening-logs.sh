#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
from pathlib import Path

CHECKS = [
    (Path('Docs/PersonaKit/Development/logs/gardening-events.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-events.jsonl'), 'GARDENING_BASE'),
    (Path('Docs/PersonaKit/Development/logs/gardening-health-snapshots.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-health-snapshots.jsonl'), 'HEALTH_SNAPSHOT_PROFILE'),
    (Path('Docs/PersonaKit/Development/logs/gardening-recommendations.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-recommendations.jsonl'), 'RECOMMENDATION_PROFILE'),
    (Path('Docs/PersonaKit/Development/logs/gardening-recommendation-feedback.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-recommendation-feedback.jsonl'), 'RECOMMENDATION_FEEDBACK_PROFILE'),
    (Path('Docs/PersonaKit/Development/logs/gardening-pack-coverage.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-pack-coverage.jsonl'), 'PACK_COVERAGE_PROFILE'),
    (Path('Docs/PersonaKit/Development/logs/gardening-policy-conflicts.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-policy-conflicts.jsonl'), 'POLICY_CONFLICT_PROFILE'),
    (Path('Docs/PersonaKit/Development/logs/gardening-safety-preflight.schema.json'), Path('Docs/PersonaKit/Development/logs/gardening-safety-preflight.jsonl'), 'SAFETY_PREFLIGHT_PROFILE'),
    (Path('Docs/PersonaKit/Development/logs/git-history-gardener.schema.json'), Path('Docs/PersonaKit/Development/logs/git-history-gardener.jsonl'), 'GIT_HISTORY_PROFILE'),
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


def check_monotonic_entry_ids(entries: list[dict], label: str) -> list[str]:
    errors: list[str] = []
    previous: int | None = None

    for idx, entry in enumerate(entries, start=1):
        entry_id = entry.get('entryId')
        if not isinstance(entry_id, str) or '-' not in entry_id:
            continue
        suffix = entry_id.rsplit('-', maxsplit=1)[-1]
        if not suffix.isdigit():
            continue
        current = int(suffix)
        if previous is not None and current <= previous:
            errors.append(
                f'{label}: line {idx}: entryId {entry_id!r} is not strictly monotonic '
                f'(previous numeric suffix {previous})'
            )
        previous = current

    return errors


def load_json_file(path: Path) -> dict:
    obj = json.loads(path.read_text())
    if not isinstance(obj, dict):
        raise ValueError(f'{path} is not a JSON object')
    return obj


def load_json_entities(directory: Path, pattern: str) -> tuple[dict[str, dict], list[str]]:
    errors: list[str] = []
    entities: dict[str, dict] = {}
    for path in sorted(directory.glob(pattern)):
        try:
            obj = load_json_file(path)
        except Exception as exc:
            errors.append(f'PACK_LOAD: {path}: {exc}')
            continue
        entity_id = obj.get('id')
        if not isinstance(entity_id, str) or not entity_id:
            errors.append(f'PACK_LOAD: {path}: missing string id')
            continue
        if entity_id in entities:
            errors.append(f'PACK_LOAD: duplicate id {entity_id!r} in {path}')
            continue
        entities[entity_id] = obj
    return entities, errors


def check_pack_reference_integrity() -> tuple[list[str], dict[str, int], list[str]]:
    errors: list[str] = []
    unresolved: list[str] = []

    personas, load_errors = load_json_entities(Path('.personakit/Packs/personas'), '*.persona.json')
    errors.extend(load_errors)
    kits, load_errors = load_json_entities(Path('.personakit/Packs/kits'), '*.kit.json')
    errors.extend(load_errors)
    directives, load_errors = load_json_entities(Path('.personakit/Packs/directives'), '*.directive.json')
    errors.extend(load_errors)
    intents, load_errors = load_json_entities(Path('.personakit/Packs/intents'), '*.intent.json')
    errors.extend(load_errors)
    skills, load_errors = load_json_entities(Path('.personakit/Packs/skills'), '*.skill.json')
    errors.extend(load_errors)

    essential_ids = {path.stem for path in sorted(Path('.personakit/Packs/essentials').glob('*.md'))}
    sessions: list[dict] = []
    for path in sorted(Path('.personakit/Sessions').glob('*.session.json')):
        try:
            sessions.append(load_json_file(path))
        except Exception as exc:
            errors.append(f'PACK_LOAD: {path}: {exc}')

    def missing_ref(source: str, owner: str, ref_kind: str, ref_id: str):
        msg = f'{source}: {owner} references missing {ref_kind} {ref_id!r}'
        errors.append(msg)
        unresolved.append(msg)

    for persona_id, persona in personas.items():
        for kit_id in persona.get('defaultKitIds', []):
            if kit_id not in kits:
                missing_ref('COVERAGE', f'persona:{persona_id}', 'kit', str(kit_id))

    for kit_id, kit in kits.items():
        for essential_id in kit.get('essentialIds', []):
            if essential_id not in essential_ids:
                missing_ref('COVERAGE', f'kit:{kit_id}', 'essential', str(essential_id))

    for intent_id, intent in intents.items():
        for essential_id in intent.get('includesEssentialIds', []):
            if essential_id not in essential_ids:
                missing_ref('COVERAGE', f'intent:{intent_id}', 'essential', str(essential_id))
        for skill_id in intent.get('requiresSkillIds', []):
            if skill_id not in skills:
                missing_ref('COVERAGE', f'intent:{intent_id}', 'skill', str(skill_id))

    for directive_id, directive in directives.items():
        for intent_id in directive.get('requiresIntentTemplateIds', []):
            if intent_id not in intents:
                missing_ref('COVERAGE', f'directive:{directive_id}', 'intent', str(intent_id))
        for skill_id in directive.get('requiresSkillIds', []):
            if skill_id not in skills:
                missing_ref('COVERAGE', f'directive:{directive_id}', 'skill', str(skill_id))

    for session in sessions:
        session_id = str(session.get('id', '<unknown-session>'))
        persona_id = session.get('personaId')
        directive_id = session.get('directiveId')
        if persona_id not in personas:
            missing_ref('COVERAGE', f'session:{session_id}', 'persona', str(persona_id))
        if directive_id not in directives:
            missing_ref('COVERAGE', f'session:{session_id}', 'directive', str(directive_id))

    counts = {
        'personas': len(personas),
        'kits': len(kits),
        'directives': len(directives),
        'intents': len(intents),
        'skills': len(skills),
        'essentials': len(essential_ids),
        'sessions': len(sessions),
    }
    return errors, counts, unresolved


def check_policy_safety_invariants() -> list[str]:
    errors: list[str] = []

    directives = {}
    for path in sorted(Path('.personakit/Packs/directives').glob('*.directive.json')):
        obj = load_json_file(path)
        directives[obj.get('id')] = obj
    intents = {}
    for path in sorted(Path('.personakit/Packs/intents').glob('*.intent.json')):
        obj = load_json_file(path)
        intents[obj.get('id')] = obj
    persona = load_json_file(Path('.personakit/Packs/personas/pack-gardener.persona.json'))

    for directive_id in ['tend-packs-and-sessions', 'maintain-rosie-worktree-upkeep-loop']:
        directive = directives.get(directive_id)
        if not directive:
            errors.append(f'POLICY: missing directive {directive_id!r}')
            continue
        steps = directive.get('steps', [])
        if not any(isinstance(step, dict) and step.get('requiresReview') is True for step in steps):
            errors.append(f'POLICY: directive {directive_id!r} has no explicit requiresReview stop point')

    rosie_directive = directives.get('maintain-rosie-worktree-upkeep-loop')
    if rosie_directive:
        intent_ids = rosie_directive.get('requiresIntentTemplateIds', [])
        if 'rosie-worktree-upkeep-review' not in intent_ids:
            errors.append(
                "POLICY: Rosie upkeep directive must require 'rosie-worktree-upkeep-review' intent"
            )

    for intent_id in ['pack-maintenance-review', 'rosie-worktree-upkeep-review']:
        intent = intents.get(intent_id)
        if not intent:
            errors.append(f'POLICY: missing intent {intent_id!r}')
            continue
        risk = intent.get('risk') if isinstance(intent.get('risk'), dict) else {}
        if risk.get('requiresHumanReview') is not True:
            errors.append(f'POLICY: intent {intent_id!r} must require human review')

    rosie_intent = intents.get('rosie-worktree-upkeep-review')
    if rosie_intent:
        params = rosie_intent.get('parameters', [])
        required_params = {
            item.get('name')
            for item in params
            if isinstance(item, dict) and item.get('required') is True
        }
        for required_name in ['phaseLabel', 'laneBranch', 'integrationBranch']:
            if required_name not in required_params:
                errors.append(
                    f'POLICY: rosie-worktree-upkeep-review missing required parameter {required_name!r}'
                )

        essential_ids = set(rosie_intent.get('includesEssentialIds', []))
        if 'rosie-worktree-upkeep-standards' not in essential_ids:
            errors.append(
                "POLICY: rosie-worktree-upkeep-review must include 'rosie-worktree-upkeep-standards'"
            )

    default_kits = set(persona.get('defaultKitIds', []))
    if 'pack-gardener-core' not in default_kits:
        errors.append("POLICY: Rosie persona must include default kit 'pack-gardener-core'")

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


def expected_priority(total_score: int) -> str:
    if total_score >= 32:
        return 'high'
    if total_score >= 22:
        return 'medium'
    return 'low'


def check_recommendation_scoring(entries: list[dict]) -> list[str]:
    errors: list[str] = []
    groups: dict[tuple[str, str, str], list[dict]] = {}

    for idx, entry in enumerate(entries, start=1):
        prefix = f'RECOMMENDATION_PROFILE: line {idx}'
        risk = entry.get('riskScore')
        impact = entry.get('driftImpactScore')
        urgency = entry.get('urgencyScore')
        effort = entry.get('effortScore')
        total_score = entry.get('totalScore')
        priority = entry.get('priority')

        if all(isinstance(x, int) for x in [risk, impact, urgency, effort, total_score]):
            expected_score = (risk * 3) + (impact * 3) + (urgency * 2) + (5 - effort)
            if total_score != expected_score:
                errors.append(
                    f'{prefix}: totalScore {total_score} does not match expected {expected_score} '
                    '(model R3-I3-U2-E1)'
                )
            expected_prio = expected_priority(total_score)
            if priority != expected_prio:
                errors.append(
                    f'{prefix}: priority {priority!r} does not match expected {expected_prio!r} '
                    f'for totalScore {total_score}'
                )

        key = (
            str(entry.get('date', '')),
            str(entry.get('sessionId', '')),
            str(entry.get('rankingSetId', '')),
        )
        groups.setdefault(key, []).append(entry)

    for key, group in groups.items():
        ranks: list[int] = []
        rank_to_entry: dict[int, dict] = {}

        for entry in group:
            rank = entry.get('rank')
            if not isinstance(rank, int):
                continue
            ranks.append(rank)
            rank_to_entry[rank] = entry

        if len(ranks) != len(group):
            errors.append(f'RECOMMENDATION_PROFILE: group {key} has non-integer rank values')
            continue

        sorted_ranks = sorted(ranks)
        expected_ranks = list(range(1, len(group) + 1))
        if sorted_ranks != expected_ranks:
            errors.append(
                f'RECOMMENDATION_PROFILE: group {key} rank set {sorted_ranks} '
                f'does not match expected contiguous ranks {expected_ranks}'
            )
            continue

        expected_order = sorted(
            group,
            key=lambda item: (-int(item.get('totalScore', -1)), str(item.get('entryId', '')))
        )
        for expected_rank, expected_entry in enumerate(expected_order, start=1):
            actual_entry = rank_to_entry.get(expected_rank)
            if not actual_entry:
                errors.append(
                    f'RECOMMENDATION_PROFILE: group {key} missing entry at rank {expected_rank}'
                )
                continue
            if actual_entry.get('entryId') != expected_entry.get('entryId'):
                errors.append(
                    f'RECOMMENDATION_PROFILE: group {key} rank {expected_rank} expected '
                    f"{expected_entry.get('entryId')!r} but found {actual_entry.get('entryId')!r}"
                )

    return errors


def check_feedback_references(feedback_entries: list[dict], recommendation_entries: list[dict]) -> list[str]:
    errors: list[str] = []
    recommendation_ids = {
        entry.get('entryId')
        for entry in recommendation_entries
        if isinstance(entry.get('entryId'), str)
    }

    for idx, entry in enumerate(feedback_entries, start=1):
        recommendation_id = entry.get('recommendationId')
        if not isinstance(recommendation_id, str):
            continue
        if recommendation_id not in recommendation_ids:
            errors.append(
                f'RECOMMENDATION_FEEDBACK_PROFILE: line {idx}: recommendationId '
                f'{recommendation_id!r} missing from recommendation stream'
            )

    return errors


def check_coverage_snapshot_alignment(
    coverage_entries: list[dict],
    derived_counts: dict[str, int],
    unresolved_references: list[str]
) -> list[str]:
    errors: list[str] = []
    latest = coverage_entries[-1]
    counts = latest.get('counts') if isinstance(latest.get('counts'), dict) else {}
    for key, expected in derived_counts.items():
        actual = counts.get(key)
        if actual != expected:
            errors.append(
                f'PACK_COVERAGE_PROFILE: latest snapshot count {key}={actual!r} '
                f'does not match derived {expected!r}'
            )

    unresolved_count = latest.get('unresolvedReferenceCount')
    if unresolved_count != len(unresolved_references):
        errors.append(
            'PACK_COVERAGE_PROFILE: latest unresolvedReferenceCount '
            f'{unresolved_count!r} does not match derived {len(unresolved_references)!r}'
        )

    expected_status = 'pass' if not unresolved_references else 'fail'
    if latest.get('coverageStatus') != expected_status:
        errors.append(
            f'PACK_COVERAGE_PROFILE: latest coverageStatus {latest.get("coverageStatus")!r} '
            f'does not match expected {expected_status!r}'
        )

    return errors


def check_policy_conflict_snapshot_alignment(policy_entries: list[dict], policy_errors: list[str]) -> list[str]:
    errors: list[str] = []
    latest = policy_entries[-1]
    expected_count = len(policy_errors)
    if latest.get('conflictCount') != expected_count:
        errors.append(
            f'POLICY_CONFLICT_PROFILE: latest conflictCount {latest.get("conflictCount")!r} '
            f'does not match derived {expected_count!r}'
        )
    expected_status = 'pass' if expected_count == 0 else 'fail'
    if latest.get('status') != expected_status:
        errors.append(
            f'POLICY_CONFLICT_PROFILE: latest status {latest.get("status")!r} '
            f'does not match expected {expected_status!r}'
        )
    return errors


def check_safety_preflight_snapshot_alignment(safety_entries: list[dict], policy_errors: list[str]) -> list[str]:
    errors: list[str] = []
    latest = safety_entries[-1]

    if latest.get('laneBranch') != 'rosies-garden':
        errors.append(
            f'SAFETY_PREFLIGHT_PROFILE: laneBranch {latest.get("laneBranch")!r} '
            "must be 'rosies-garden'"
        )
    if latest.get('integrationBranch') != 'main':
        errors.append(
            f'SAFETY_PREFLIGHT_PROFILE: integrationBranch {latest.get("integrationBranch")!r} '
            "must be 'main'"
        )
    if not isinstance(latest.get('reviewGateCount'), int) or latest.get('reviewGateCount') < 2:
        errors.append('SAFETY_PREFLIGHT_PROFILE: reviewGateCount must be >= 2')

    required_intents = {'pack-maintenance-review', 'rosie-worktree-upkeep-review'}
    intent_set = set(latest.get('requiresHumanReviewIntents', []))
    if not required_intents.issubset(intent_set):
        errors.append(
            'SAFETY_PREFLIGHT_PROFILE: requiresHumanReviewIntents missing required values '
            f'{sorted(required_intents - intent_set)}'
        )

    blocked = latest.get('blockedActions')
    if not isinstance(blocked, list):
        errors.append('SAFETY_PREFLIGHT_PROFILE: blockedActions must be a list')
    elif policy_errors and len(blocked) == 0:
        errors.append('SAFETY_PREFLIGHT_PROFILE: blockedActions should be non-empty when policy errors exist')

    expected_status = 'pass' if not policy_errors else 'fail'
    if latest.get('status') != expected_status:
        errors.append(
            f'SAFETY_PREFLIGHT_PROFILE: latest status {latest.get("status")!r} '
            f'does not match expected {expected_status!r}'
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
    all_errors.extend(check_monotonic_entry_ids(entries, label))

if 'GARDENING_BASE' in parsed and 'GIT_HISTORY_PROFILE' in parsed:
    all_errors.extend(check_mirror_consistency(parsed['GARDENING_BASE'], parsed['GIT_HISTORY_PROFILE']))

if 'RECOMMENDATION_PROFILE' in parsed:
    all_errors.extend(check_recommendation_scoring(parsed['RECOMMENDATION_PROFILE']))

if 'RECOMMENDATION_FEEDBACK_PROFILE' in parsed and 'RECOMMENDATION_PROFILE' in parsed:
    all_errors.extend(
        check_feedback_references(
            parsed['RECOMMENDATION_FEEDBACK_PROFILE'],
            parsed['RECOMMENDATION_PROFILE']
        )
    )

coverage_errors, coverage_counts, unresolved_references = check_pack_reference_integrity()
all_errors.extend(coverage_errors)

policy_errors = check_policy_safety_invariants()
all_errors.extend(policy_errors)

if 'PACK_COVERAGE_PROFILE' in parsed:
    all_errors.extend(
        check_coverage_snapshot_alignment(
            parsed['PACK_COVERAGE_PROFILE'],
            coverage_counts,
            unresolved_references
        )
    )

if 'POLICY_CONFLICT_PROFILE' in parsed:
    all_errors.extend(check_policy_conflict_snapshot_alignment(parsed['POLICY_CONFLICT_PROFILE'], policy_errors))

if 'SAFETY_PREFLIGHT_PROFILE' in parsed:
    all_errors.extend(check_safety_preflight_snapshot_alignment(parsed['SAFETY_PREFLIGHT_PROFILE'], policy_errors))

if all_errors:
    print('GARDENING_LOGS_CHECK:FAIL')
    for err in all_errors:
        print(err)
    raise SystemExit(1)

print('GARDENING_LOGS_CHECK:PASS')
PY
