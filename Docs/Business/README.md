# Venture Studio Docs

Status: Active  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

This folder is the operating system for "what next?" decisions:

- ethical boundaries
- opportunity scoring
- backlog and next actions

## Daily Operating Loop

Run commands from the repository root.

1. Run the session context:
   - `swift run personakit export --root .personakit --session venture-studio-daily`
2. Generate three opportunities.
3. Score each one using [Idea-Scorecard.md](./Idea-Scorecard.md).
4. Update [Opportunity-Backlog.md](./Opportunity-Backlog.md).
5. Pick one focus candidate for the next 14-day MVP cycle.

## Documents

- [Ethics.md](./Ethics.md)
- [Idea-Scorecard.md](./Idea-Scorecard.md)
- [Opportunity-Backlog.md](./Opportunity-Backlog.md)
- [personakit-venture-cycle-01.md](./personakit-venture-cycle-01.md)

## Current Selected Venture

- `VS-006`: PersonaKit agency pilot
- Working brief: [personakit-venture-cycle-01.md](./personakit-venture-cycle-01.md)

## Ground Rules

- One active build target at a time.
- No "hidden scope" changes without explicit review.
- External messaging must protect internal IP and roadmap details.

Related docs:

- [Documentation Style Guide](../STYLEGUIDE.md)
- [Collaboration Charter](../Development/Collaboration-Charter.md)
