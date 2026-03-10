# Worktree Squad Cheat Sheet

Status: Active  
Owner: AJ + Samwise  
Last Reviewed: 2026-03-09

## Purpose

This is the fast mental model for how Samwise, AJ's Trusted Partner, Worktree
Squad Lead, and Rosie work together.

## Core Roles

```mermaid
flowchart LR
    AJ["AJ"] --> SAM["Samwise\nAJ Trusted Partner"]
    SAM --> SQL["Worktree Squad Lead\nbounded execution + staff review"]
    SAM --> ROSIE["Rosie\nretrospective gardener"]
```

1. `AJ`
   - approval authority
   - protected `main` owner
2. `Samwise`
   - AJ's Trusted Partner and orchestration lead
   - defines gates and stop points
   - decides whether work is ready to advance
3. `Worktree Squad Lead`
   - runs one bounded work loop inside an isolated worktree
   - performs staff-level code review before gate advancement
4. `Rosie`
   - reads diary and retrospective artifacts
   - proposes improvements for the next iteration

## Main Loop

```mermaid
flowchart TD
    A["AJ objective"] --> B["Samwise oversight"]
    B --> C["One bounded work item"]
    C --> D["Worktree Squad Lead delivery loop"]
    D --> E["Verification\nbuild / test / snapshot"]
    E --> F["Review triage\nblocker / major / minor"]
    F --> G["Gate decision"]
    G --> H["Retrospective"]
    H --> I["Rosie gardening"]
    I --> J["Recommendations for next cycle"]
    J --> B
```

## What Happens In A Delivery Loop

1. Samwise assigns one bounded work item.
2. Worktree Squad Lead confirms branch/worktree scope and commit mode.
3. Worktree Squad Lead executes the work item.
4. Verification evidence is recorded.
5. Staff-level review findings are recorded.
6. Gate decision is made.
7. A loop log entry is appended.
8. If the assignment is done, a retrospective is required.

## Evidence Trail

```mermaid
flowchart LR
    DL["Delivery loop"] --> LOOP["worktree-squad-loops.jsonl"]
    RETRO["Retrospective"] --> RETROLOG["worktree-squad-retrospectives.jsonl"]
    DIARY["samwise-diary.jsonl"] --> ROSIE["Rosie retrospective gardening"]
    LOOP --> ROSIE
    RETROLOG --> ROSIE
    ROSIE --> REPORT["recommendation report"]
```

## Safety Rules

1. Primary repository `main` is protected and never changed without explicit AJ
   permission.
2. Isolated worktrees are valid execution scopes.
3. Commit mode must always be explicit:
   - `per-commit-approval`
   - `worktree-auto-commit-approved`
4. One bounded work item per loop unless AJ expands scope.
5. Blockers unresolved by the next checkpoint must escalate to AJ.

## Named Multi-Worktree Mode

When AJ approves a bounded multi-worktree execution strategy, each approved
non-`main` worktree must have:

- a named milestone or scope boundary
- explicit commit mode
- explicit promotion rules back toward `main`

Rules:

1. `main` remains protected and manual-review only.
2. Standing commit authority applies only inside the explicitly approved
   non-`main` worktrees.
3. One worktree may be designated the official milestone branch.
4. A second worktree may be designated exploratory, but it does not silently
   redefine the milestone branch.
5. Scope changes, destructive git actions, or promotion decisions still
   escalate to AJ.

## Sessions To Use

1. Samwise oversight:
   - [samwise-worktree-squad-oversight.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/samwise-worktree-squad-oversight.session.json)
2. Squad execution:
   - [worktree-squad-delivery.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/worktree-squad-delivery.session.json)
3. Squad retrospective:
   - [worktree-squad-retrospective.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/worktree-squad-retrospective.session.json)
4. Squad calibration:
   - [worktree-squad-calibration.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/worktree-squad-calibration.session.json)
5. Rosie retrospective gardening:
   - [rosie-retrospective-garden.session.json](/Users/ajself/Code/PersonaKit/.personakit/Sessions/rosie-retrospective-garden.session.json)

## Key Contracts

1. Gating and authorization:
   - [worktree-squad-gating-contract.md](/Users/ajself/Code/PersonaKit/.personakit/Packs/essentials/worktree-squad-gating-contract.md)
2. Loop and retrospective logging:
   - [worktree-squad-loop-log-contract.md](/Users/ajself/Code/PersonaKit/.personakit/Packs/essentials/worktree-squad-loop-log-contract.md)
3. Rosie recommendation mining:
   - [rosie-retrospective-gardening-contract.md](/Users/ajself/Code/PersonaKit/.personakit/Packs/essentials/rosie-retrospective-gardening-contract.md)

## Validation

1. PersonaKit structure:
   - `swift run personakit validate --root .personakit`
2. Squad loop logs:
   - `Scripts/check-worktree-squad-logs.sh`
3. Gardening logs:
   - `Scripts/check-gardening-logs.sh`
4. Hiring logs:
   - `Scripts/check-persona-hiring-logs.sh`

## Fast Read

If you only remember one thing:

1. Samwise decides and supervises.
2. Worktree Squad Lead executes one bounded loop and reviews it.
3. Rosie learns from the diary and retrospectives and recommends how to do the
   next loop better.
