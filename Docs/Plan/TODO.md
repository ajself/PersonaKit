# TODO

Last Updated: 2026-03-07

## Purpose

Keep plan execution focused. This file is the ordered queue for open plans.

## Open Plan Queue (In Order)

### 1) VentureStudio Pilot Validation (Done; pending AJ signoff)

Plan source:

- `Workspaces/VentureStudio/Docs/Plan/pilot-validation-plan.md`

Objective:

- Run the full planning-management pilot and close gates `G0` through `G5` with evidence.

Actions:

1. Run all four scenarios (happy path, blocker path, deferred-major path, daily gardening loop).
2. Record scenario outcomes and evidence links.
3. Update gate states in `Workspaces/VentureStudio/Docs/Plan/README.md`.
4. Produce pilot report recommendation: `ready for phase-2` or `needs revision`.

Exit criteria:

1. All pilot scenarios are executed and logged.
2. Gate evidence is complete.
3. Phase-2 decision is explicit.

Execution note:

- Completed on 2026-03-07; see `Workspaces/VentureStudio/Docs/Plan/pilot-validation-report.md`.

### 2) PersonaKit MCP Conversation Plan (Done; pending AJ signoff)

Plan source:

- `Docs/Plan/personakit-mcp-conversation-plan.md`

Objective:

- Complete M3 (E2E tests, error UX, starter flows) and close the remaining active MCP plan work.

Actions:

1. Add/confirm golden and integration coverage for common MCP conversation scenarios.
2. Document error contracts with recovery hints.
3. Create `Docs/MCP/Starter-Flows.md` and verify examples.
4. Update plan status to complete when acceptance criteria are met.

Exit criteria:

1. M3 acceptance criteria are all met.
2. Plan status no longer active.

Execution note:

- Completed on 2026-03-07; see `Docs/MCP/Starter-Flows.md`, `Docs/MCP/Error-Contracts.md`, and `Tests/Features/MCP/MCPConversationFlowTests.swift`.

### 3) Xcode Host Integration Closeout (Execute Next)

Plan source:

- `Docs/Plan/xcode-host-package-integration-plan.md`

Objective:

- Close final interactive caveats and retire this plan.

Actions:

1. Run interactive app smoke in Xcode.
2. Confirm host test coverage state (latest headless run passed: `xcodebuildmcp macos test --workspace-path PersonaKit.xcworkspace --scheme PersonaKit --configuration Debug --derived-data-path .sim/DerivedData`).
3. Record pass/fail outcomes in the plan doc.
4. Archive plan after confirmation.

Exit criteria:

1. Interactive checks are explicitly recorded.
2. Plan can be archived without open caveats.

Execution note:

- Headless host test preflight passed on 2026-03-07; remaining work is the interactive app smoke confirmation.

### 4) Git History Gardening Cadence (Ongoing)

Plan sources:

- `Docs/Plan/git-history-gardener-proposals.md`
- `Docs/Plan/git-history-gardener-log.md`

Objective:

- Keep history cleanup proposal-first and approval-gated.

Actions:

1. Run analysis-only passes for future ranges as needed.
2. Keep proposals explicit (`pending`/`approved`/`rejected`).
3. Execute only approved proposals.
4. Validate logs with `Scripts/check-gardening-logs.sh` after each pass.

Exit criteria:

1. Every history edit is proposal-backed and approval-tracked.
2. Log contract remains valid.

## Plan Hygiene Rules

1. Keep only active plans in `Docs/Plan/`.
2. Move completed plans to `Docs/Plan/Archive/`.
3. Keep this TODO ordered and current after each milestone.
