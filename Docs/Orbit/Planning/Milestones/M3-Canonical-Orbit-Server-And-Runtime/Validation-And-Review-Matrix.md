# M3 Validation And Review Matrix

Status: Accepted
Milestone: `M3`
Owner: `studio-coverage-architect`
Primary Execution Persona: `studio-integration-coordinator`
Last Updated: 2026-03-18

## Purpose

Define the deterministic validation and review work required to close `M3`
honestly.

## Validation Matrix

| Area | Owner | Evidence type | Pass condition | Disqualifier |
| --- | --- | --- | --- | --- |
| Canonical ownership boundary | `architectural-editor` | architecture review note | server-owned and client-owned state are explicit and coherent | dual truth or ambiguous ownership remains |
| Stack posture fidelity | `architectural-editor` and `samwise` | stack-conformance review note | implementation stays inside the approved `Swift + Vapor + Postgres`, self-hosted, monolith-first posture | framework, database, deployment, or infrastructure drift appears without approval |
| Runtime persistence slice | `studio-coverage-architect` | schema and persistence validation | minimum phase-1 runtime records persist and reconstruct correctly | required runtime slice is incomplete or unstable |
| Authored versus runtime separation | `architectural-editor` | boundary review artifact | PersonaKit authored truth remains outside server-owned runtime semantics | server begins re-owning contract truth |
| Realtime projection semantics | `studio-reliability-engineer` | reconnect and event tests | events reflect durable transitions and support replayable recovery | event stream acts like a second truth source |
| Replay and stale-client recovery | `studio-reliability-engineer` and `studio-coverage-architect` | replay, reconnect, and stale-client tests | clients converge by snapshot plus replay | recovery depends on local guesswork |
| macOS client cutover quality | `senior-swiftui-engineer` and `venture-product-steward` | migration walkthrough and product review | the room remains believable after server cutover | migration weakens room semantics or product clarity |
| Trace continuity | `studio-coverage-architect` | golden flow review plus tests | response trace semantics survive the server migration unchanged in meaning | trace becomes weaker, blurrier, or debug-only |
| Artifact storage abstraction discipline | `architectural-editor` | storage-boundary review | runtime truth and large artifact storage remain cleanly separated | first backend choice distorts the architecture |
| Evidence completeness | `samwise` | closeout packet audit | architecture, reliability, validation, and migration artifacts all exist | milestone is called ready on backend confidence alone |

## Review Sequence

### Pass 1. Architecture Review

Questions:

- is canonical ownership explicit enough to prevent dual truth?
- are authored and runtime boundaries still sharp after migration?
- is the implementation still honoring the approved stack posture rather than
  improvising it?

### Pass 2. Reliability Review

Questions:

- does reconnect and replay work by design rather than luck?
- do failure modes degrade visibly without faking durable success?

### Pass 3. Product Continuity Review

Questions:

- does the macOS room still feel like Orbit after server cutover?
- did the migration preserve `M1` and `M2` semantics rather than merely preserve
  a UI shell?

### Pass 4. Coverage And Closeout Review

Questions:

- do the tests and artifacts support the claims being made?
- is the migration baseline strong enough for `M4`, `M5`, and later mobile work?

## Confidence Split

Before `M3` is treated as complete, reviewers should be able to state separate
confidence for:

- runtime correctness
- replay and recovery reliability
- product continuity
- process and evidence quality

`M3` should not close on a single blended `looks server-backed` judgment.
