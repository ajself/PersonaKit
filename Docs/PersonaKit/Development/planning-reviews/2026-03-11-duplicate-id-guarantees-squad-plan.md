# Squad Planning Review: Duplicate-ID Guarantees

Date: `2026-03-11`  
Objective: Make duplicate-ID behavior guarantees explicit across the PersonaKit
surfaces that matter, instead of discovering renderer behavior by surprise.  
Workspace or initiative scope: `PersonaKit` core loader, Studio editor, and
renderer-facing identity surfaces  
Session ID: `samwise-squad-planning`  
Reviewer: `AJ`  
Handoff status: `awaiting-aj-review`

## Objective Boundary

1. Goal summary:
   - Turn the current scattered duplicate-ID behavior into an explicit,
     reviewable guarantee covering load-time validation, scope precedence,
     editor behavior, and renderer-facing collection inputs.
2. In scope:
   - Existing duplicate-ID guarantees in core loading and workspace flows
   - Studio surfaces that render ID-backed collections or normalize ID lists
   - A bounded squad plan for implementation, review, and validation
3. Out of scope:
   - Broad refactors unrelated to duplicate-ID guarantees
   - New PersonaKit structural artifacts unless AJ explicitly asks for them
   - Execution in the protected `main` worktree
4. Hard constraints:
   - Keep behavior deterministic and guarantees explicit
   - Prefer small reviewable diffs
   - Use an isolated non-main worktree before any delivery loop begins
   - Require delegated execution handoffs to fail closed when PersonaKit
     grounding is unavailable

## Proposed Squad

1. Role:
   - Owner: `samwise`
   - Responsibility boundary: shaping, orchestration, review gate management
   - Why this owner: Samwise owns the planning lane, stop points, and next
     session handoff discipline
2. Role:
   - Owner: `worktree-squad-lead`
   - Responsibility boundary: execution lane lead, validation evidence, review
     triage
   - Why this owner: the worktree squad loop already provides bounded execution
     with explicit acceptance criteria and protected-branch controls
3. Role:
   - Owner: `architectural-editor`
   - Responsibility boundary: invariant review and boundary enforcement
   - Why this owner: duplicate-ID guarantees need an explicit architectural
     contract instead of implicit renderer assumptions
4. Role:
   - Owner: `studio-boundary-guardian`
   - Responsibility boundary: editor/store boundary hardening for ID-bearing
     inputs
   - Why this owner: the risk is not just core loading, but how Studio surfaces
     accept and normalize identity data before render
5. Role:
   - Owner: `senior-swiftui-engineer`
   - Responsibility boundary: SwiftUI collection and renderer-facing
     implementation
   - Why this owner: renderer surprises are most likely to appear where SwiftUI
     collections consume duplicate or unstable IDs
6. Role:
   - Owner: `studio-coverage-architect`
   - Responsibility boundary: deterministic regression tests for guarantee
     boundaries
   - Why this owner: the goal is to prove guarantees explicitly instead of
     relying on local memory
7. Role:
   - Owner: `AJ`
   - Responsibility boundary: approval and execution handoff gate
   - Why this owner: execution remains human-gated and cannot begin from this
     planning pass alone

## Role Coverage Review

1. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `samwise` plus `samwise-squad-planning` already own bounded
     planning and stop-point behavior
   - Reverse-interview required: No
2. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `worktree-squad-lead` already owns gated delivery loops,
     deterministic evidence, and staff-level review triage
   - Reverse-interview required: No
3. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `architectural-editor` is explicitly a review-first invariant
     guardian for SwiftUI projects
   - Reverse-interview required: No
4. Role:
   - Coverage status: `covered`
   - Confidence: Medium-High
   - Evidence: `studio-boundary-guardian` covers view/store boundaries and small
     hardening diffs across Studio surfaces
   - Reverse-interview required: No
5. Role:
   - Coverage status: `covered`
   - Confidence: Medium-High
   - Evidence: `senior-swiftui-engineer` is the best fit for renderer-facing
     collection hardening and small SwiftUI diffs
   - Reverse-interview required: No
6. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `studio-coverage-architect` specializes in deterministic tests
     for high-risk graph and scope behavior
   - Reverse-interview required: No
7. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: AJ approval is already required by the active planning and
     worktree contracts
   - Reverse-interview required: No

## Missing Roles And Artifact Gaps

1. Missing role or gap:
   - Recommended artifact type: `none`
   - Priority: Medium
   - First implementation step: use the existing Samwise planning and worktree
     squad sessions; keep the work focused on code, tests, and explicit
     invariants rather than creating new PersonaKit structure

## First Checkpoint Plan

1. Checkpoint or milestone:
   - Owner: `worktree-squad-lead`
   - Definition of done:
     - duplicate-ID guarantees are written down for the relevant loader,
       workspace, editor, and renderer-facing surfaces
     - any renderer-facing collection that currently depends on implicit
       uniqueness is hardened to receive explicit guarantees or fail before
       render
     - targeted regression tests cover duplicate-ID behavior in core loading,
       scope precedence, and at least one Studio UI/editor path
     - delegated execution lanes receive a compact handoff packet that names
       persona/session grounding, write scope, acceptance criteria, validation,
       and stop points
     - PersonaKit-dependent delegated work uses a clear fallback ladder:
       live MCP first, approved static export second, otherwise stop as
       `grounding-blocked`
     - build and test evidence is attached before any gate advancement
   - Dependencies:
     - this planning review
     - a dedicated non-main worktree
     - current duplicate-ID evidence in core and Studio tests
     - either live PersonaKit MCP access for delegated lanes or a prepared
       frozen PersonaKit export artifact for bounded fallback use
   - Review gate:
     - `architectural-editor` reviews the invariant boundary before merge
     - AJ reviews the checkpoint before any execution handoff or commit
   - Validation owner:
     - `worktree-squad-lead`
   - Validation commands or evidence:
     - `swift run personakit validate --root .personakit`
     - `swift test --filter RegistryTests/registryDetectsDuplicateIDs`
     - `swift test --filter ListCommandTests/listSessionsPrefersProjectScopeForDuplicateIDs`
     - `swift test --filter WorkspaceStoreLibraryActionsTests/createPersonaRejectsDuplicateIDBeforeSave`
     - `swift test`
     - `xcodebuildmcp macos build --workspace-path PersonaKit.xcworkspace --scheme PersonaKitStudio`

## Delegated Handoff Strategy

1. Delegated execution or review lanes should be MCP-first:
   - the parent lane names the persona and required session or directive
   - the delegated agent loads PersonaKit context before acting
   - the delegated handoff packet stays compact and explicit
2. If PersonaKit MCP is unavailable, a bounded fallback is allowed:
   - the parent lane prepares a frozen PersonaKit export on disk or passes the
     same resolved context directly as input
   - the export should include persona, directive, associated kits,
     essentials, scope boundary, and validation expectations
   - the delegated lane should treat the export as a static snapshot and avoid
     improvising beyond it
3. Static export fallback is acceptable only for bounded implementation or
   review work:
   - planning, hiring, remediation, or open-ended context discovery should not
     silently degrade to cached context
4. If neither live MCP nor an approved static export is available:
   - the delegated lane stops and reports `grounding-blocked`
   - the parent lane keeps the checkpoint blocked until grounding is restored

## Unknowns And Risks

1. Current duplicate-ID behavior is partly explicit in loader and editor flows,
   but it is not yet collected into one visible guarantee envelope, which is
   exactly how renderer surprises stay alive.
2. The active workspace is repository `main`, so execution from the current
   location would violate the worktree-squad gating contract.
3. Some renderer-facing lists may already be safe because upstream pipelines
   normalize or de-duplicate IDs, but that safety is not obvious enough from
   the call sites today.
4. Static PersonaKit export fallback is workable for bounded delegated lanes,
   but it introduces staleness risk and should not be treated as equivalent to
   live MCP for planning-heavy or discovery-heavy work.
5. Quality gate result: `pass-with-notes` because the objective, owners, next
   action, and validation plan are explicit, but execution is intentionally
   blocked pending AJ review plus a non-main worktree scope.

## Recommended Next Session

1. Session ID:
   - Why next: `samwise-worktree-squad-oversight` is the right handoff because
     it lets Samwise supervise a bounded delivery loop in a dedicated non-main
     worktree while preserving AJ review gates
   - Expected inputs:
     - this planning review
     - current branch/worktree scope and authorization mode
     - the duplicate-ID artifact set listed below
     - delegated handoff packet fields and grounding mode for each staffed lane
   - Expected outputs:
     - one bounded implementation work item
     - validation evidence and review triage
     - queued next actions for any remaining duplicate-ID surfaces
     - explicit `grounding-blocked` disposition if a delegated lane cannot load
       live MCP and no approved static export exists

## Evidence

1. Artifact references:
   - `.personakit/Sessions/samwise-squad-planning.session.json`
   - `.personakit/Sessions/samwise-worktree-squad-oversight.session.json`
   - `.personakit/Sessions/worktree-squad-delivery.session.json`
   - `.personakit/Packs/personas/samwise.persona.json`
   - `.personakit/Packs/personas/worktree-squad-lead.persona.json`
   - `.personakit/Packs/personas/architectural-editor.persona.json`
   - `.personakit/Packs/personas/studio-boundary-guardian.persona.json`
   - `.personakit/Packs/personas/senior-swiftui-engineer.persona.json`
   - `.personakit/Packs/personas/studio-coverage-architect.persona.json`
   - `Sources/Shared/ContextCore/Registry.swift`
   - `Sources/Features/Studio/UI/PersonaEditorView.swift`
   - `Sources/Features/Studio/UI/SessionEditorFormSectionsView.swift`
   - `Sources/Features/Studio/UI/WorkspaceRelationshipMapPanelView.swift`
   - `Tests/Shared/Core/RegistryTests.swift`
   - `Tests/Features/CLI/ListCommandTests.swift`
   - `Tests/Features/Studio/WorkspaceStoreLibraryActionsTests.swift`
2. Relevant hiring review IDs:
   - None
3. Related planning review ID:
   - `SPR-0004`
4. Related logs or continuity notes:
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
   - `Docs/PersonaKit/Development/partner-context-log.md`
