# Venture Studio Session Directory

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Provide a compact, phase-grouped index of sessions in
`Workspaces/VentureStudio/.personakit`.

## Venture Workflows

- `venture-studio-daily` - owner: `venture-studio-founder`

## Story Pilot Team Workflows

- `story-product-kickoff` - owner: `story-product-lead`
- `story-design` - owner: `story-web-designer`
- `story-build` - owner: `story-web-engineer`
- `story-architecture-review` - owner: `story-architecture-reviewer`
- `story-qa` - owner: `story-qa-engineer`
- `story-vqa` - owner: `story-vqa-lead`

## Story Pilot Recommended Order

1. `story-product-kickoff`
2. `story-design`
3. `story-build`
4. `story-architecture-review`
5. `story-qa`
6. `story-vqa`

## Validation Commands

Run from repository root:

- `swift run personakit validate --root Workspaces/VentureStudio/.personakit`
- `swift run personakit export --root Workspaces/VentureStudio/.personakit --session venture-studio-daily`
- `ls Workspaces/VentureStudio/.personakit/Sessions`
