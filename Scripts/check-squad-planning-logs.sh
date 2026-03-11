#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import json
import re
from pathlib import Path

SCHEMA_PATH = Path("Docs/PersonaKit/Development/logs/squad-planning-reviews.schema.json")
JSONL_PATH = Path("Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl")
SESSIONS_DIR = Path(".personakit/Sessions")
DIRECTIVES_DIR = Path(".personakit/Packs/directives")
HIRING_LOG_PATH = Path("Docs/PersonaKit/Development/logs/persona-hiring-reviews.jsonl")
STRICT_WORKSTREAM_ENTRY_FLOOR = 7


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


def load_hiring_ids():
    if not HIRING_LOG_PATH.exists():
        return set(), [f"missing hiring log {HIRING_LOG_PATH}"]

    entries, errors = parse_jsonl(HIRING_LOG_PATH)
    ids = set()
    for entry in entries:
        entry_id = entry.get("entryId")
        if isinstance(entry_id, str):
            ids.add(entry_id)
    return ids, errors


def check_cross_refs(entries: list[dict], hiring_ids: set[str]):
    errors = []
    for idx, entry in enumerate(entries, start=1):
        report_path = entry.get("reportPath")
        if isinstance(report_path, str) and report_path:
            if not Path(report_path).exists():
                errors.append(f"line {idx}: reportPath does not exist: {report_path}")

        next_session_id = entry.get("nextSessionId")
        if isinstance(next_session_id, str) and next_session_id:
            session_path = SESSIONS_DIR / f"{next_session_id}.session.json"
            if not session_path.exists():
                errors.append(
                    f"line {idx}: nextSessionId does not resolve to a session file: {next_session_id}"
                )

        hiring_review_ids = entry.get("relatedHiringReviewIds", [])
        if isinstance(hiring_review_ids, list):
            for review_id in hiring_review_ids:
                if review_id not in hiring_ids:
                    errors.append(
                        f"line {idx}: relatedHiringReviewId does not exist in hiring log: {review_id}"
                    )
    return errors


def check_delegated_handoffs(entries: list[dict]):
    errors = []
    for idx, entry in enumerate(entries, start=1):
        delegated_role_names = entry.get("delegatedRoleNames", [])
        delegated_handoffs = entry.get("delegatedHandoffs", [])

        if delegated_role_names and not isinstance(delegated_role_names, list):
            errors.append(f"line {idx}: delegatedRoleNames must be an array when present")
            continue

        if delegated_handoffs and not isinstance(delegated_handoffs, list):
            errors.append(f"line {idx}: delegatedHandoffs must be an array when present")
            continue

        if delegated_role_names:
            if not delegated_handoffs:
                errors.append(
                    f"line {idx}: delegatedRoleNames are present but delegatedHandoffs is missing"
                )
                continue

            handoff_roles = set()
            for handoff_idx, handoff in enumerate(delegated_handoffs, start=1):
                prefix = f"line {idx}: delegatedHandoffs[{handoff_idx}]"
                if not isinstance(handoff, dict):
                    errors.append(f"{prefix} is not an object")
                    continue

                role = handoff.get("role")
                if not isinstance(role, str) or not role:
                    errors.append(f"{prefix}: missing non-empty role")
                else:
                    handoff_roles.add(role)

                required_session = handoff.get("requiredSessionId")
                required_directive = handoff.get("requiredDirectiveId")
                if not required_session and not required_directive:
                    errors.append(
                        f"{prefix}: either requiredSessionId or requiredDirectiveId is required"
                    )

                grounding_mode = handoff.get("groundingMode")
                if grounding_mode == "static-export":
                    fallback_paths = handoff.get("fallbackArtifactPaths", [])
                    if not isinstance(fallback_paths, list) or not fallback_paths:
                        errors.append(
                            f"{prefix}: static-export handoffs require fallbackArtifactPaths"
                        )
                    snapshot_date = handoff.get("snapshotDate")
                    if not isinstance(snapshot_date, str) or not re.match(
                        r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
                        snapshot_date,
                    ):
                        errors.append(
                            f"{prefix}: static-export handoffs require snapshotDate in YYYY-MM-DD format"
                        )

            missing_roles = sorted(set(delegated_role_names) - handoff_roles)
            if missing_roles:
                errors.append(
                    f"line {idx}: delegatedHandoffs missing roles declared in delegatedRoleNames {missing_roles}"
                )

        elif delegated_handoffs:
            errors.append(
                f"line {idx}: delegatedHandoffs present without delegatedRoleNames declaration"
            )

    return errors


def entry_suffix(entry_id: str):
    suffix = entry_id.rsplit("-", maxsplit=1)[-1]
    if suffix.isdigit():
        return int(suffix)
    return None


def load_session(session_id: str):
    session_path = SESSIONS_DIR / f"{session_id}.session.json"
    if not session_path.exists():
        return None, [f"session file does not exist: {session_path}"]

    try:
        session = json.loads(session_path.read_text())
    except Exception as exc:
        return None, [f"failed to parse session file {session_path}: {exc}"]

    if not isinstance(session, dict):
        return None, [f"session file is not an object: {session_path}"]

    return session, []


def load_directive_workstream(session_id: str):
    session, errors = load_session(session_id)
    if errors:
        return None, errors

    directive_id = session.get("directiveId")
    if not isinstance(directive_id, str) or not directive_id:
        return None, [f"session {session_id} missing directiveId"]

    directive_path = DIRECTIVES_DIR / f"{directive_id}.directive.json"
    if not directive_path.exists():
        return None, [f"directive file does not exist: {directive_path}"]

    try:
        directive = json.loads(directive_path.read_text())
    except Exception as exc:
        return None, [f"failed to parse directive file {directive_path}: {exc}"]

    if not isinstance(directive, dict):
        return None, [f"directive file is not an object: {directive_path}"]

    workstream = directive.get("workstream")
    if workstream is None:
        return None, []
    if not isinstance(workstream, dict):
        return None, [f"directive {directive_id} has non-object workstream metadata"]

    return workstream, []


def derive_next_session_ids(workstream: dict, current_session_id: str):
    edges = workstream.get("edges", [])
    if not isinstance(edges, list):
        return []

    next_ids = []
    for edge in edges:
        if not isinstance(edge, dict):
            continue
        if edge.get("fromSessionId") == current_session_id:
            to_session_id = edge.get("toSessionId")
            if isinstance(to_session_id, str):
                next_ids.append(to_session_id)
    return next_ids


def check_workstream(entries: list[dict]):
    errors = []

    for idx, entry in enumerate(entries, start=1):
        prefix = f"line {idx}"
        entry_id = entry.get("entryId")
        session_id = entry.get("sessionId")

        if not isinstance(entry_id, str) or not isinstance(session_id, str):
            continue

        directive_workstream, load_errors = load_directive_workstream(session_id)
        for error in load_errors:
            errors.append(f"{prefix}: {error}")
        if load_errors:
            continue

        workstream = entry.get("workstream")
        suffix = entry_suffix(entry_id)
        requires_workstream = (
            suffix is not None
            and suffix >= STRICT_WORKSTREAM_ENTRY_FLOOR
            and directive_workstream is not None
        )

        if requires_workstream and workstream is None:
            errors.append(
                f"{prefix}: workstream is required for workstream-aware entries at or beyond SPR-{STRICT_WORKSTREAM_ENTRY_FLOOR:04d}"
            )
            continue

        if workstream is None:
            continue
        if not isinstance(workstream, dict):
            errors.append(f"{prefix}: workstream must be an object when present")
            continue
        if directive_workstream is None:
            errors.append(
                f"{prefix}: workstream is present but session {session_id} does not resolve directive workstream metadata"
            )
            continue

        expected_next_session_ids = derive_next_session_ids(directive_workstream, session_id)
        actual_next_session_ids = workstream.get("nextSessionIds", [])

        if workstream.get("id") != directive_workstream.get("id"):
            errors.append(f"{prefix}: workstream.id does not match directive workstream id")
        if workstream.get("phase") != directive_workstream.get("phase"):
            errors.append(f"{prefix}: workstream.phase does not match directive workstream phase")
        if workstream.get("currentSessionId") != session_id:
            errors.append(f"{prefix}: workstream.currentSessionId must match sessionId")
        if workstream.get("entrySessionId") != directive_workstream.get("entrySessionId"):
            errors.append(
                f"{prefix}: workstream.entrySessionId does not match directive workstream entrySessionId"
            )
        if actual_next_session_ids != expected_next_session_ids:
            errors.append(
                f"{prefix}: workstream.nextSessionIds does not match directive-derived next sessions {expected_next_session_ids}"
            )

        expected_closeout = directive_workstream.get("requiredCloseoutSessionId")
        actual_closeout = workstream.get("requiredCloseoutSessionId")
        if actual_closeout != expected_closeout:
            errors.append(
                f"{prefix}: workstream.requiredCloseoutSessionId does not match directive workstream requiredCloseoutSessionId"
            )

        next_session_id = entry.get("nextSessionId")
        if isinstance(next_session_id, str) and next_session_id not in actual_next_session_ids:
            errors.append(
                f"{prefix}: nextSessionId is not included in workstream.nextSessionIds"
            )

        compatibility_closeout = entry.get("requiredCloseoutSessionId")
        if compatibility_closeout is not None and compatibility_closeout != actual_closeout:
            errors.append(
                f"{prefix}: requiredCloseoutSessionId does not match workstream.requiredCloseoutSessionId"
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
        hiring_ids, hiring_errors = load_hiring_ids()
        all_errors.extend(hiring_errors)
        all_errors.extend(validate_schema(schema, entries))
        all_errors.extend(check_entry_ids(entries))
        all_errors.extend(check_cross_refs(entries, hiring_ids))
        all_errors.extend(check_delegated_handoffs(entries))
        all_errors.extend(check_workstream(entries))

if all_errors:
    print("SQUAD_PLANNING_LOGS_CHECK:FAIL")
    for err in all_errors:
        print(err)
    raise SystemExit(1)

print("SQUAD_PLANNING_LOGS_CHECK:PASS")
PY
