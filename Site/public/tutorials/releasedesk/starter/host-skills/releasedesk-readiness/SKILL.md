# ReleaseDesk Readiness Skill

Use this skill when a host agent is asked to diagnose ReleaseDesk release-readiness behavior or implement a readiness fix that has already been approved.

This skill describes a procedure. It does not authorize edits by itself.

## Required Inputs

- The ReleaseDesk project root.
- The failing or suspicious readiness behavior.
- The current mode from the human or host: diagnosis only, implementation approved, or review only.

## Steps

1. Inspect `data/release.json` to understand the release tasks, owners, required flags, and blocked status.
2. Inspect `src/releaseRules.js` before editing anything.
3. Run `node test/run-tests.mjs` and capture the failing readiness expectation.
4. If the mode is diagnosis only, stop with the suspected rule, evidence, and smallest safe fix.
5. If implementation is approved, make the smallest change that fixes readiness behavior.
6. Run `node test/run-tests.mjs` again.
7. Report what changed, which validation ran, and any remaining risk.

## Guardrails

- Do not publish, tag, deploy, notarize, or modify credentials.
- Do not edit files unless the current mode explicitly approves implementation.
- Do not change release data to make a test pass unless the task explicitly asks for data changes.
- Do not add unrelated UI behavior while fixing readiness rules.
- If the human asked for review only, do not turn this procedure into a fix.

## Closeout

Report:

- The readiness rule that changed or was reviewed.
- The validation result from `node test/run-tests.mjs`.
- Any product question that still needs a human decision.
