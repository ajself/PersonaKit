# Orbit Meeting Transcript Protocol

Use this essential when an AI participant is working in Orbit meeting notes.

## Scope

This protocol governs turn-based meeting transcripts stored under:

- `Docs/Orbit/Meeting Notes/`

It applies to both:

- creating new meeting notes from the template
- editing active meeting notes after a participant requests a response or
  document update

## Source Of Truth

The formatting source of truth for Orbit meeting notes is:

- `Docs/Orbit/Meeting Notes/_template.md`

If a meeting file, memory, or nearby example appears inconsistent with the
template, re-read `_template.md` and follow it.

Do not normalize meeting structure from memory.

## Required Pre-Edit Discipline

Before editing any Orbit meeting note:

1. Re-read `Docs/Orbit/Meeting Notes/_template.md`.
2. Identify whether the requested edit affects:
   - shared meeting scaffold, or
   - a turn owned by the current speaker
3. Confirm the exact field order and section layout from `_template.md`.
4. Then apply the smallest allowed edit.

## Turn Ownership Rules

Meeting turns are speaker-owned.

- Do not edit another speaker's turn content unless AJ explicitly instructs it.
- Do not rewrite another speaker's `Message`, `Summary`, or
  `Requested Next Speaker` fields for style or normalization.
- Fixing obvious formatting mistakes in prior turns is allowed only when the
  change does not alter the speaker's meaning.
- When in doubt, append a new turn instead of rewriting an older one.

## Transcript Discipline

When working in a meeting note:

1. Append one new turn at a time unless AJ explicitly requests scaffold-only
   cleanup.
2. Keep turn structure aligned with `_template.md`.
3. Preserve attribution for every turn.
4. Keep changes bounded to the requested meeting and related artifacts.
5. Conclude a meeting explicitly before starting the next one.

## Shared Scaffold Rules

The following sections may be updated when needed to keep the meeting coherent:

- `Purpose`
- `Agenda`
- `Context`
- `Working Notes`
- `Decisions`
- `Open Questions`
- `Action Items`
- `Closeout`

These updates should remain factual, brief, and aligned with the actual turn
log.

## Non-Goals

- Do not treat meeting notes as free-form chat transcripts.
- Do not silently reorder or reformat prior turns beyond the template rules.
- Do not use meeting-note cleanup as a reason to broaden scope into unrelated
  documents.
- Do not conclude a meeting implicitly.
