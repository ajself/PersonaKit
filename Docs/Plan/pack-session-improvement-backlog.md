# Pack and Session Improvement Backlog

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Capture prioritized follow-up improvements for Packs and Sessions discovered
during maintenance passes.

## Backlog

| ID | Priority | Item | Rationale | Target IDs | Status |
| --- | --- | --- | --- | --- | --- |
| PSG-001 | High | Add a compact "session directory" doc grouped by workflow stage | Session count is growing; navigation friction will increase without grouping | `Docs/README.md`, `Docs/Development/session-directory.md`, `.personakit/Sessions/*` | Done (2026-03-07) |
| PSG-002 | Medium | Add lifecycle states for sessions (`active`, `candidate`, `deprecated`) | Prevents stale sessions from appearing production-ready | Session schema/docs convention | Done (2026-03-07) |
| PSG-003 | Medium | Add a recurring closeout checklist entry for pack/session maintenance | Keeps maintenance from being skipped at phase transitions | `Docs/Plan/TODO.md`, `pack-gardener-log.md` | Open |
| PSG-004 | Medium | Add per-session ownership notes in session directory | Speeds handoff decisions and maintenance accountability | `Docs/Development/session-directory.md` | Done (2026-03-07) |
| PSG-005 | Medium | Add deterministic JSONL log contract for git-history gardening passes | Enables machine-processable review trails and future guardrail analytics | `Docs/Plan/git-history-gardener-log.md`, `Docs/Plan/logs/git-history-gardener.jsonl`, `Docs/Plan/logs/git-history-gardener.schema.json` | Done (2026-03-07) |
| PSG-006 | Medium | Centralize JSONL gardening log model for all gardening sessions | Prevents duplicated tooling and enables shared analytics across maintenance domains | `.personakit/Packs/essentials/gardening-log-contract.md`, `Docs/Plan/logs/gardening-events.jsonl`, `Docs/Plan/logs/gardening-events.schema.json` | Done (2026-03-07) |
| PSG-007 | Medium | Define Samwise end-of-day closeout protocol and diary contract | Improves continuity, reflection quality, and next-day restart speed | `.personakit/Packs/personas/samwise.persona.json`, `.personakit/Packs/directives/run-samwise-daily-closeout.directive.json`, `Docs/Plan/logs/samwise-diary.jsonl`, `Docs/Plan/logs/samwise-diary.schema.json` | Done (2026-03-07) |
| PSG-008 | High | Enforce commit authorization policy: per-commit AJ approval by default, with optional auto-commit only for AJ-approved non-main dedicated worktrees | Prevents unauthorized commit actions while supporting scoped automation in approved lane worktrees only | `.personakit/Packs/personas/samwise.persona.json`, `.personakit/Packs/essentials/partner-trust-contract.md`, `.personakit/Packs/essentials/tools-and-constraints.md`, `.personakit/Packs/essentials/non-goals.md`, `.personakit/Packs/directives/maintain-partner-sync-and-handoffs.directive.json`, `.personakit/Packs/directives/run-samwise-daily-closeout.directive.json`, `.personakit/Packs/intents/partner-sync-review.intent.json` | Done (2026-03-07) |
| PSG-009 | Medium | Create a reusable Gardening v2 checklist and require it in pack maintenance passes | Improves consistency across drift scanning, proposal quality, policy sync, validation, and closeout evidence | `.personakit/Packs/essentials/gardening-v2-checklist.md`, `.personakit/Packs/essentials/pack-gardening-standards.md`, `.personakit/Packs/kits/pack-gardener-core.kit.json`, `.personakit/Packs/intents/pack-maintenance-review.intent.json`, `.personakit/Packs/directives/tend-packs-and-sessions.directive.json` | Done (2026-03-07) |
| PSG-010 | Medium | Explicitly define self-gardening behavior and approval parity in gardener pack files | Prevents ambiguity about whether gardener-owned artifact updates require the same human-gated flow | `.personakit/Packs/essentials/gardening-v2-checklist.md`, `.personakit/Packs/essentials/pack-gardening-standards.md`, `.personakit/Packs/directives/tend-packs-and-sessions.directive.json`, `.personakit/Packs/intents/pack-maintenance-review.intent.json` | Done (2026-03-07) |
| PSG-011 | Low | Name the pack gardener persona for human-readable collaboration while preserving stable IDs | Improves readability in exports/reviews without changing machine references | `.personakit/Packs/personas/pack-gardener.persona.json` | Done (2026-03-07) |
| PSG-012 | High | Codify Rosie dedicated worktree upkeep loop with lane/main sync guardrails | Makes the `rosies-garden` operating model explicit, repeatable, and review-gated across routine gardening cycles | `.personakit/Packs/essentials/rosie-worktree-upkeep-standards.md`, `.personakit/Packs/intents/rosie-worktree-upkeep-review.intent.json`, `.personakit/Packs/directives/maintain-rosie-worktree-upkeep-loop.directive.json`, `.personakit/Sessions/rosie-worktree-upkeep.session.json`, `.personakit/Packs/kits/pack-gardener-core.kit.json`, `Docs/Development/session-directory.md` | Done (2026-03-07) |
| PSG-013 | High | Align Rosie upkeep scope boundaries across kit, intent, directive, and persona | Prevents lane policy bleed, ambiguous integration location, and branch-target drift during upkeep cycles | `.personakit/Packs/kits/pack-gardener-core.kit.json`, `.personakit/Packs/directives/maintain-rosie-worktree-upkeep-loop.directive.json`, `.personakit/Packs/intents/rosie-worktree-upkeep-review.intent.json`, `.personakit/Packs/personas/pack-gardener.persona.json` | Done (2026-03-07) |
| PSG-014 | Low | Make Rosie upkeep commit/lane guardrails explicit in directive and persona text | Reduces interpretation drift by promoting inherited constraints to first-class wording where upkeep decisions are made | `.personakit/Packs/directives/maintain-rosie-worktree-upkeep-loop.directive.json`, `.personakit/Packs/personas/pack-gardener.persona.json` | Done (2026-03-07) |
