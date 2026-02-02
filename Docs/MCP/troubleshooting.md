Troubleshooting

Root not set
- Symptom: errors that PERSONAKIT_ROOT is missing or empty.
- Fix: set PERSONAKIT_ROOT to an absolute path that contains Packs/.

Packs directory missing
- Symptom: errors that Packs/ does not exist under the root.
- Fix: point PERSONAKIT_ROOT to the kit root that contains Packs/.

Resource not found
- Symptom: a resource read fails with a message that includes the URI and an expected Packs/... path.
- Fix: confirm the file exists under Packs/ and that the id matches the filename.

Prompts fail due to missing ids
- Symptom: prompts/get fails with a missing persona, directive, kit, intent, skill, or essential id.
- Fix: verify the ids exist in the kit and that referenced files are present.
- Tip: run the CLI validator to identify missing references before using MCP.
