# Interaction Quality Rubric

Use this rubric to judge whether an in-app planning board experience is approaching Trello/GitHub-Issues interaction quality.

## Scoring Dimensions (100 Total)

1. Navigation clarity (`15`)
2. Lane workflow clarity (`15`)
3. Ticket CRUD flow quality (`20`)
4. Move/reorder reliability (`20`)
5. Keyboard and accessibility efficiency (`15`)
6. Performance perception (`15`)

## Scoring Method

1. Score each dimension from `0-5`.
2. Convert each dimension to weighted points.
3. Sum weighted points for total score (`0-100`).
4. Record one evidence note for each dimension.

## Quality Thresholds

1. `>= 85` and blockers = `0`: `parity-ready`
2. `75-84` and blockers = `0`: `ship-with-notes`
3. `< 75` or blockers > `0`: `revise-before-ship`

## Blocker Conditions

1. User can lose ticket data during create/edit/move/delete.
2. Drag/drop or move action causes ambiguous ticket state.
3. Core ticket flow cannot be completed without pointer input.
4. Board state fails to persist or reload deterministically.
5. Primary actions are unclear enough to prevent task completion.

## Guardrails

- Do not claim Trello-level parity without evidence in every dimension.
- Do not hide blockers under aggregate score.
- Keep findings tied to concrete user flows and reproduction steps.
