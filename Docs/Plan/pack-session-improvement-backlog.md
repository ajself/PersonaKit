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
| PSG-002 | Medium | Add lifecycle states for sessions (`active`, `candidate`, `deprecated`) | Prevents stale sessions from appearing production-ready | Session schema/docs convention | Open |
| PSG-003 | Medium | Add a recurring closeout checklist entry for pack/session maintenance | Keeps maintenance from being skipped at phase transitions | `Docs/Plan/TODO.md`, `pack-gardener-log.md` | Open |
| PSG-004 | Medium | Add per-session ownership notes in session directory | Speeds handoff decisions and maintenance accountability | `Docs/Development/session-directory.md` | Done (2026-03-07) |
| PSG-005 | Medium | Add deterministic JSONL log contract for git-history gardening passes | Enables machine-processable review trails and future guardrail analytics | `Docs/Plan/git-history-gardener-log.md`, `Docs/Plan/logs/git-history-gardener.jsonl`, `Docs/Plan/logs/git-history-gardener.schema.json` | Done (2026-03-07) |
| PSG-006 | Medium | Centralize JSONL gardening log model for all gardening sessions | Prevents duplicated tooling and enables shared analytics across maintenance domains | `.personakit/Packs/essentials/gardening-log-contract.md`, `Docs/Plan/logs/gardening-events.jsonl`, `Docs/Plan/logs/gardening-events.schema.json` | Done (2026-03-07) |
| PSG-007 | Medium | Define Samwise end-of-day closeout protocol and diary contract | Improves continuity, reflection quality, and next-day restart speed | `.personakit/Packs/personas/samwise.persona.json`, `.personakit/Packs/directives/run-samwise-daily-closeout.directive.json`, `Docs/Plan/logs/samwise-diary.jsonl`, `Docs/Plan/logs/samwise-diary.schema.json` | Done (2026-03-07) |
