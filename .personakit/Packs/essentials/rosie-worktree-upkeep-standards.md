# Rosie Worktree Upkeep Standards

Use this runtime standard for ongoing Rosie gardening work in the dedicated lane worktree.
For the full upkeep loop, see `rosie-worktree-upkeep-standards-reference`.

## Core Rules

1. Keep Rosie gardening isolated in the approved non-`main` lane.
2. Preserve traceability from lane commits to `main` integration.
3. Keep human review gates explicit around history-altering actions.

## Required Upkeep Loop

1. Confirm the active lane scope and AJ approval.
2. Sync the lane from latest `main`.
3. Run bounded gardening updates with required logs.
4. Run coverage, policy-conflict, and safety-preflight checks before integration.
5. Pause for AJ review before any history-altering lane-to-main step.
6. Record validation status and residual risks after the cycle.
