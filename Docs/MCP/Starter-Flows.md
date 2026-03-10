# Starter Flows

This guide provides practical MCP-first recipes for common PersonaKit conversations.

## Flow 1: "List local personas, then choose identity"

Goal: "List personakit personas local to this project and then select X."

1. Start MCP with local-first scope:
   - `personakit mcp --root /absolute/path/to/.personakit`
2. Read `personakit://catalog/personas`.
3. Choose an id from `ids[]`.
4. Validate fit:
   - call tool `personakit_explain_entity` with `entityType=persona` and `id=<persona-id>`.
5. Load identity context:
   - call tool `personakit_export` with `personaId=<persona-id>` and `directiveId=<directive-id>`.

## Flow 2: "What should I use for this goal?"

Goal: session recommendation.

1. Call tool `personakit_recommend_session` with:
   - `goal` (required)
   - `limit` (optional, `1..20`)
2. Use top recommendation `sessionId`.
3. Call `personakit_trace_session` with that `sessionId` to inspect resolved kits, intents, skills, and essentials.

## Flow 3: Compare two entities before selecting

Goal: explain tradeoffs before picking a persona, directive, or kit.

1. Call tool `personakit_compare_entities`.
2. Provide one shared `entityType` and both ids (`leftId`, `rightId`).
3. Read `scalarDifferences` and `listDifferences` to identify deterministic deltas.

## Flow 4: Troubleshoot missing id errors fast

1. Read matching catalog endpoint first:
   - `personakit://catalog/personas`
   - `personakit://catalog/directives`
   - `personakit://catalog/kits`
   - `personakit://catalog/sessions`
2. Retry tool call with an id from the catalog.
3. If startup fails, verify scope root includes `Packs/` and review [Troubleshooting](./troubleshooting.md).

## Flow 5: Review a session by id or path

Goal: normalize a session target, trace it, and prepare a session-stack review.

1. Call tool `personakit_resolve_session_ref` with:
   - `sessionRef`
     - canonical session id, or
     - session-file path
2. Use `normalizedSessionId`, `personaId`, and `directiveId` from the result.
3. Call `personakit_trace_session` with `sessionId=<normalizedSessionId>`.
4. Call `personakit_export` with:
   - `personaId=<personaId>`
   - `directiveId=<directiveId>`
   - `kits=<kitOverrides>` when present
5. If `personakit_resolve_session_ref` or `personakit_trace_session` fails, treat the review as MCP-blocked and stop instead of freehanding the graph manually.

## Determinism Notes

- Catalog ids and list outputs are stable and sorted.
- Recommendation ranking is deterministic and documented in output policy fields.
- For MCP, only one scope is active at a time (no project+global merge).
