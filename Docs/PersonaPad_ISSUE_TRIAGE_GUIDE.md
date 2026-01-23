# PersonaPad Issue Triage Guide (v1)

PersonaPad is a **small, local, deterministic utility**.
This guide exists to keep the project maintainable.

## Fast accept / fast reject rules

### Accept (usually)
- Bugs that affect determinism, parity, correctness, or clarity
- Improvements to error messages, docs, examples, and release tooling
- Small UI ergonomics that reduce friction in the core workflow:
  “select persona → tweak context → copy prompt”

### Defer (usually)
- New prompt section types or major schema expansion
- Big UI reworks that don’t improve the core workflow
- Anything that adds long-term support obligations

### Reject (v1 / probably forever)
- AI provider execution, chat, or runtime features
- Cloud sync, accounts, remote packs, telemetry/analytics
- Prompt “optimization”, rewriting, or auto-tuning
- Plugin systems, marketplaces, or “platform” features
- Collaboration / sharing / team workspaces

## Standard responses

### “Thanks, but out of scope”
> Thanks for the suggestion! PersonaPad is intentionally a local, deterministic prompt composer.
> This request would move it toward execution/sync/optimization, which we’re explicitly not building.
> Closing to protect scope and long-term maintainability.

### “Good idea, but later”
> This seems useful, but it expands schema/UI surface area beyond v1.
> Marking as deferred until after v1 hardening (determinism, parity, clarity).

### “Yes, that’s a bug”
> Confirmed — this affects determinism/parity/correctness. Treating as a v1 bug.
> A minimal repro (persona + inputs) would help a lot.
