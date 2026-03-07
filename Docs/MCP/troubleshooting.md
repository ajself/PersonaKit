# Troubleshooting

## Root not set

- Symptom: MCP cannot find a local or global PersonaKit scope.
- Fix: provide `--root <path>`, set `PERSONAKIT_ROOT`, or run from a project with `.personakit/`.

## Packs directory missing

- Symptom: startup error says root must contain `Packs/`.
- Fix: point `--root` or `PERSONAKIT_ROOT` at a PersonaKit root containing `Packs/`.

## Project/global fallback controls

- Symptom: expected global fallback did not occur.
- Fix: ensure `--no-global` is not set.
- Symptom: expected local project scope was skipped.
- Fix: ensure `--no-project` is not set.

## Override compatibility

- Symptom: error says `PERSONAKIT_ROOT_OVERRIDE` requires `PERSONAKIT_ROOT`.
- Fix: set `PERSONAKIT_ROOT` to a valid PersonaKit root path when using `PERSONAKIT_ROOT_OVERRIDE=1`.

## Resource not found

- Symptom: resource read fails with a message that includes the URI and expected `Packs/...` path.
- Fix: confirm the file exists under `Packs/` and that id matches filename.

## Tool call returns "not found"

- Symptom: tool error line like `<entityType> not found: <id>`.
- Fix: read the matching catalog endpoint first (`personakit://catalog/<type>`) and retry with a listed id.

## Tool call returns no sessions found

- Symptom: recommendation fails with `No session files found in active scopes.`
- Fix: add at least one `Sessions/*.session.json` file to the active scope.

## Prompt or tool argument failures

- Symptom: missing/invalid argument errors.
- Fix: use required argument names and types from tool/prompt schemas; re-run with only supported keys.

See also:

- [Starter Flows](./Starter-Flows.md)
- [Error Contracts](./Error-Contracts.md)
