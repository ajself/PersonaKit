# Persona Coverage Matrix

Status: Draft
Milestone: `M0`
Owner: `samwise`
Last Updated: 2026-03-18

## Purpose

Map each roadmap milestone to its execution owner, required supporting or review
personas, and any unresolved persona gaps that must be handled before delegation.

## Coverage Matrix

| Milestone | Primary owner | Supporting and review personas | Coverage status | Notes |
| --- | --- | --- | --- | --- |
| `M0` | `samwise` | `venture-product-steward`, `architectural-editor` | covered | Planning and scaffolding lane |
| `M1` | `architectural-editor` | `senior-swiftui-engineer`, `studio-coverage-architect` | covered | Execution owner and review ring are clear |
| `M2` | `senior-swiftui-engineer` | `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect` | covered with collaborator dependency | Depends on frozen `ProdDoc` decision for founding roster language |
| `M3` | `studio-integration-coordinator` | `architectural-editor`, `senior-swiftui-engineer`, `studio-reliability-engineer`, `studio-coverage-architect` | covered | Good fit for canonical runtime migration |
| `M4` | `orbit-meeting-coordinator` | `samwise`, `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect` | blocked on missing persona | Do not delegate until persona exists or AJ approves substitute |
| `M5` | `orbit-meeting-coordinator` | `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect` | blocked on missing persona | Same gap as `M4`, but more consequential |
| `M6` | `venture-product-steward` | `senior-swiftui-engineer`, `studio-interaction-quality-lead`, `architectural-editor` | covered | Product-heavy milestone with architecture review |
| `M7` | `worktree-squad-lead` | `samwise`, `venture-product-steward`, `studio-integration-coordinator`, `studio-coverage-architect` | conditionally covered | Reassess whether `orbit-workstream-runner` is needed before delegation scale increases |
| `M8` | `orbit-memory-gardener` | `venture-product-steward`, `studio-interaction-quality-lead`, `studio-coverage-architect` | blocked on missing persona | Required before journaling and memory review are delegated |
| `M9` | `orbit-memory-gardener` | `architectural-editor`, `studio-coverage-architect`, `venture-product-steward` | blocked on missing persona | Same missing persona as `M8` |
| `M10` | `orbit-memory-gardener` | `samwise`, `venture-product-steward`, `studio-coverage-architect` | blocked on missing persona | Same missing persona as `M8` and `M9` |
| `M11` | `senior-swiftui-engineer` | `studio-reliability-engineer`, `venture-product-steward`, `studio-coverage-architect` | covered | Depends on `M3` being truly stable |
| `M12` | `senior-swiftui-engineer` | `studio-interaction-quality-lead`, `orbit-meeting-coordinator`, `venture-product-steward` | blocked on missing persona | Can plan early, cannot delegate fully without coordinator persona |
| `M13` | `orbit-platform-operator` or `orbit-server-steward` | `studio-integration-coordinator`, `studio-reliability-engineer`, `studio-coverage-architect`, `architectural-editor` | blocked on missing persona | Need one approved platform operations identity |

## Cross-Cutting Gaps

### `ProdDoc` collaborator identity

Current state:

- the product and first-checkpoint docs treat `ProdDoc` as a durable founding
  collaborator
- PersonaKit currently has `venture-product-steward`, not a formal `ProdDoc`
  persona

Impact:

- `M1` and `M2` cannot claim identity precision while this remains ambiguous

### `orbit-meeting-coordinator`

Needed for:

- `M4`
- `M5`
- part of `M12`

Why this matters:

- group-target expansion and meeting promotion are both high-risk for routing
  opacity and require a trustworthy, visible orchestration identity

### `orbit-memory-gardener`

Needed for:

- `M8`
- `M9`
- `M10`

Why this matters:

- memory staging and reuse are governance-sensitive; a generic implementation
  persona is not a strong enough substitute

### `orbit-platform-operator` or `orbit-server-steward`

Needed for:

- `M13`

Why this matters:

- deployment, restore, and operational stewardship need one explicit operations
  identity rather than an inferred blend of engineering personas

### `orbit-workstream-runner`

Needed for:

- possibly `M7`, depending on execution-lane complexity

Why this matters:

- if workstreams remain bounded and review-heavy, `worktree-squad-lead` may be
  enough
- if workstreams become a durable product identity, the generic delivery lead
  may become too stretched

## Quality Rule

This matrix is only useful if it blocks wishful thinking.

If a milestone is marked covered when it is actually persona-blocked, the matrix
has failed.
