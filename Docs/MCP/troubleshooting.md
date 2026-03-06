Troubleshooting

Root not set
- Symptom: MCP cannot find a local or global PersonaKit scope.
- Fix: provide `--root <path>`, set `PERSONAKIT_ROOT`, or run from a project with `.personakit/`.

Packs directory missing
- Symptom: errors that root must contain `Packs/`.
- Fix: point `--root` or `PERSONAKIT_ROOT` at a PersonaKit root containing `Packs/`.

Project/global fallback controls
- Symptom: expected global fallback did not occur.
- Fix: ensure `--no-global` is not set.
- Symptom: expected local project scope was skipped.
- Fix: ensure `--no-project` is not set.

Override compatibility
- Symptom: errors that `PERSONAKIT_ROOT_OVERRIDE` requires `PERSONAKIT_ROOT`.
- Fix: set `PERSONAKIT_ROOT` to a valid PersonaKit root path when using `PERSONAKIT_ROOT_OVERRIDE=1`.

Resource not found
- Symptom: a resource read fails with a message that includes the URI and an expected Packs/... path.
- Fix: confirm the file exists under Packs/ and that the id matches the filename.

Prompts fail due to missing ids
- Symptom: prompts/get fails with a missing persona, directive, kit, intent, skill, or essential id.
- Fix: verify the ids exist in the kit and that referenced files are present.
- Tip: run the CLI validator to identify missing references before using MCP.
