# TODO

Last Updated: 2026-03-07

## Purpose

Keep plan execution focused. This file is the ordered queue for open plans.

## Open Plan Queue (In Order)

### 1) Git History Gardening Cadence (Execute Next, Ongoing)

Plan source:

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

Execution note:

- Analysis pass #3 completed on 2026-03-07 with no new pending proposals.

## Completed Plans (AJ Approved 2026-03-07)

### 1) VentureStudio Pilot Validation

- Plan: `Workspaces/VentureStudio/Docs/Plan/pilot-validation-plan.md`
- Report: `Workspaces/VentureStudio/Docs/Plan/pilot-validation-report.md`
- Outcome: `ready for phase-2`

### 2) PersonaKit MCP Conversation Plan

- Archived plan: `Docs/Plan/Archive/personakit-mcp-conversation-plan.md`
- Key outputs: `Docs/MCP/Starter-Flows.md`, `Docs/MCP/Error-Contracts.md`, `Tests/Features/MCP/MCPConversationFlowTests.swift`

### 3) Xcode Host Integration Closeout

- Archived plan: `Docs/Plan/Archive/xcode-host-package-integration-plan.md`
- Key evidence: `xcodebuildmcp macos build-and-run` launch + UI smoke verification recorded before archive

## Plan Hygiene Rules

1. Keep only active plans in `Docs/Plan/`.
2. Move completed plans to `Docs/Plan/Archive/`.
3. Keep this TODO ordered and current after each milestone.
