# Squad Planning Review: M4 Dossier Hardening

Date: `2026-03-20`
Objective: Harden the `M4` Team And Squad Collaboration dossier so it becomes a
reviewable planning packet without beginning runtime-facing packet work.
Workspace or initiative scope: `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration`
plus the matching Samwise planning-review surfaces
Session ID: `samwise-squad-planning`
Reviewer: `AJ`
Handoff status: `awaiting-aj-review`

## Objective Boundary

1. Goal summary:
   - Turn the current one-file `M4` milestone into a reviewable dossier that
     names quality, validation, decisions, and packet boundaries clearly enough
     for later runtime work to stay bounded.
2. In scope:
   - Upgrade the `M4` README to the frozen dossier standard
   - Add `Quality-Bar.md`, `Validation-And-Review-Matrix.md`, and
     `Decision-Register.md`
   - Add one planning packet note for each of the five existing `M4` packets
   - Write this planning review and append one `SPR` log entry
3. Out of scope:
   - Preflight C or any runtime-facing `M4` packet work
   - `M5` meeting promotion, continuity, or `M7` workstream execution behavior
   - PersonaKit structural edits beyond the standard planning review and log
4. Hard constraints:
   - No subagents are authorized in this pass
   - Do not turn dossier hardening into runtime implementation
   - Keep `orbit-meeting-coordinator` as a real owner without promoting its
     candidate sessions
   - Keep later milestone references strictly bounded to owner/support
     availability

## Proposed Squad

1. Role:
   - Owner: `samwise`
   - Responsibility boundary: planning orchestration, dossier shaping, stop-point
     discipline
   - Why this owner: `samwise-squad-planning` is the active contract for turning
     this objective into a bounded, reviewable plan
2. Role:
   - Owner: `orbit-meeting-coordinator`
   - Responsibility boundary: milestone ownership and packet-boundary authority
   - Why this owner: `PHR-0009` now clears the missing-owner gap for `M4`
     without promoting later milestone execution
3. Role:
   - Owner: `venture-product-steward`
   - Responsibility boundary: product-scope and milestone-sequencing review
   - Why this owner: the dossier needs a clear product boundary so `M4` does not
     quietly absorb `M5` behavior
4. Role:
   - Owner: `studio-interaction-quality-lead`
   - Responsibility boundary: interaction-legibility and trust review
   - Why this owner: visible reasoning and inline collaboration quality are core
     to whether `M4` feels believable
5. Role:
   - Owner: `studio-coverage-architect`
   - Responsibility boundary: validation ownership and evidence discipline
   - Why this owner: the dossier needs a named validation matrix before any
     runtime packet can be trusted
6. Role:
   - Owner: `AJ`
   - Responsibility boundary: approval gate before any further preflight or
     runtime packet handoff
   - Why this owner: this planning pass is intentionally review-gated

## Role Coverage Review

1. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `samwise-squad-planning` already owns bounded planning, durable
     reports, machine-readable logs, and explicit stop points
   - Reverse-interview required: No
2. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `PHR-0009` plus the new coordinator review and delivery sessions
     establish a real `M4` owner without promoting runtime execution
   - Reverse-interview required: No
3. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `venture-product-steward` already owns product scope and
     milestone-quality review for planning-heavy Orbit work
   - Reverse-interview required: No
4. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `studio-interaction-quality-lead` already owns interaction-quality
     judgment and trust-oriented review language
   - Reverse-interview required: No
5. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: `studio-coverage-architect` already owns validation and regression
     proof surfaces for milestone closeout
   - Reverse-interview required: No
6. Role:
   - Coverage status: `covered`
   - Confidence: High
   - Evidence: AJ review is already required by the active planning contract and
     the current preflight boundary
   - Reverse-interview required: No

## Missing Roles And Artifact Gaps

1. Missing role or gap:
   - Recommended artifact type: `documentation-only milestone dossier artifacts`
   - Priority: High
   - First implementation step: add the missing `M4` control surfaces
     (`Quality-Bar.md`, `Validation-And-Review-Matrix.md`,
     `Decision-Register.md`, and the packet notes) before any runtime-facing
     packet is allowed to start

## First Checkpoint Plan

1. Checkpoint or milestone:
   - Owner: `samwise`
   - Definition of done:
     - the `M4` README reaches the frozen dossier standard with a quality
       standard and file map
     - `Quality-Bar.md`, `Validation-And-Review-Matrix.md`, and
       `Decision-Register.md` exist and stay bounded to `M4`
     - `Packet-01` through `Packet-05` exist as planning-only packet contracts
       with grounding, scope, write bounds, and stop points
     - `PHR-0009` is reflected only as owner-availability evidence, not as
       approval for `M5` or runtime execution
     - the planning review and `SPR-0008` log entry agree on the next-session
       gate and validation expectations
   - Dependencies:
     - `PHR-0009`
     - `RFC-0003` and `RFC-0004`
     - the accepted `M0` dossier standard and milestone templates
     - `M3` runtime-trust baseline staying intact
   - Review gate:
     - AJ reviews this dossier before any Preflight C shaping or runtime-facing
       packet handoff
     - this pass does not authorize execution or delegation
   - Validation owner:
     - `samwise`
   - Validation commands or evidence:
     - `swift run personakit validate --root .personakit`
     - `Scripts/check-squad-planning-logs.sh`
     - manual review that the `M4` file map and packet notes agree on scope,
       stop points, and non-runtime posture

## Delegated Agent Handoff Packets

No delegated roles are authorized in Preflight B.

If AJ later approves runtime-facing `M4` work, packet-specific handoffs should be
derived from the new packet notes rather than improvised from this review alone.

## Unknowns And Risks

1. The dossier is now much sharper, but AJ may still want one additional review
   artifact before authorizing the first runtime-facing packet.
2. The packet notes intentionally stay documentation-only in this pass, so the
   exact runtime write scope for Packet 1 still needs explicit approval before
   execution.
3. `M3` is cited as a prerequisite, but the exact evidence slice to carry into
   `M4` packet kickoff should be kept small so the packet does not become
   dependency soup.
4. Quality gate result: `pass-with-notes` because the dossier becomes
   review-ready and bounded, but later preflight or runtime work remains blocked
   pending AJ review.

## Recommended Next Session

1. Session ID:
   - Why next: `samwise-worktree-squad-oversight` is the right next session if
     AJ accepts the hardened dossier and explicitly authorizes one bounded
     runtime-facing `M4` packet
   - Required closeout session: `worktree-squad-retrospective`
   - Expected inputs:
     - this planning review
     - the hardened `M4` dossier files
     - explicit AJ direction about which packet may begin
     - current branch/worktree scope and authorization mode
   - Expected outputs:
     - one bounded runtime-facing packet kickoff or an explicit blocked decision
     - validation expectations and review gates for that packet
     - a clear stop if the requested packet would broaden into `M5` or later
       Orbit work

## Workstream Routing

1. Workstream:
   - Id: `worktree-squad-lifecycle`
   - Phase: `planning`
   - Current session: `samwise-squad-planning`
   - Entry session: `samwise-squad-planning`
   - Next sessions: `samwise-worktree-squad-oversight`
   - Required closeout session: `worktree-squad-retrospective`

## Evidence

1. Artifact references:
   - `.personakit/Sessions/samwise-squad-planning.session.json`
   - `.personakit/Packs/directives/assemble-squad-and-plan.directive.json`
   - `Docs/PersonaKit/Development/hiring-reviews/2026-03-20-orbit-meeting-coordinator.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/README.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Quality-Bar.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Validation-And-Review-Matrix.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Decision-Register.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Packet-01-Group-Structure-Assumptions.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Packet-02-Target-Expansion.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Packet-03-Inline-Group-Reply-Flow.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Packet-04-Participation-Roles-And-Completion-Semantics.md`
   - `Docs/Orbit/Planning/Milestones/M4-Team-And-Squad-Collaboration/Packet-05-Trust-And-Inspectability.md`
   - `Docs/Orbit/Planning/Milestones/README.md`
   - `Docs/Orbit/Planning/Milestones/_Templates/Milestone-README-Template.md`
   - `Docs/Orbit/Planning/Milestones/_Templates/Milestone-Quality-Bar-Template.md`
   - `Docs/Orbit/Planning/Milestones/_Templates/Milestone-Decision-Register-Template.md`
   - `Docs/Orbit/Planning/Milestones/_Templates/Execution-Packet-Template.md`
   - `Docs/Orbit/RFCs/RFC-0003-Workspace-Group-and-Workspace-Persona-Instance-Model.md`
   - `Docs/Orbit/RFCs/RFC-0004-Teams-Squads-and-Meeting-Coordinator.md`
2. Relevant hiring review IDs:
   - `PHR-0009`
3. Related planning review ID:
   - `SPR-0008`
4. Related logs or continuity notes:
   - `Docs/PersonaKit/Development/logs/squad-planning-reviews.jsonl`
   - `Docs/PersonaKit/Development/logs/persona-hiring-reviews.jsonl`
