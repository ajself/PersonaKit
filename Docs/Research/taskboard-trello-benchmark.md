# Taskboard Trello Benchmark

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Capture source-backed Trello behaviors that Taskboard v2 should emulate (or
explicitly defer) before implementation work starts.

## Method

1. Primary sources only: Trello and Atlassian support docs.
2. Retrieval date for this pass: 2026-03-07 (America/Chicago).
3. Publication dates are included when listed by source; otherwise marked as
   unavailable.
4. No generative images were used for this benchmark.

## Trello Baseline (Observed)

### Core model and board mechanics

1. Boards contain lists, and lists contain cards. Lists and cards are
   re-orderable and can be moved between lists and boards.
   Source: [Create a board](https://support.atlassian.com/trello/docs/adding-lists-to-a-board/),
   [Move cards or lists](https://support.atlassian.com/trello/docs/moving-cards-or-lists/).
2. Board scale guidance exists in docs: boards can hold up to 5,000 cards, but
   performance may degrade over 1,000 cards.
   Source: [Add a card to a board](https://support.atlassian.com/trello/docs/adding-cards-to-a-board/).

### Card metadata and workflow depth

1. Checklists are first-class and can include advanced checklist behavior.
   Source: [Add checklists to cards and advanced checklists](https://support.atlassian.com/trello/docs/adding-checklists-to-cards-and-advanced-checklists/).
2. Labels are first-class card metadata.
   Source: [Create and manage labels](https://support.atlassian.com/trello/docs/creating-and-managing-labels/).
3. Custom fields are available with plan-tier limits.
   Source: [Custom fields](https://support.atlassian.com/trello/docs/custom-fields/).
4. Cards support due dates/start dates and completion state.
   Source: [Add a due date or start date to a card](https://support.atlassian.com/trello/docs/adding-dates-to-cards/).
5. Cards support member assignment.
   Source: [Add a person to a card](https://support.atlassian.com/trello/docs/adding-a-member-to-a-card/).

### Search, filtering, and speed

1. Board-level filtering supports labels, members, due dates, and keywords.
   Source: [Filtering for cards on a board](https://support.atlassian.com/trello/docs/filtering-for-cards-on-a-board/).
2. Global search supports cards and boards.
   Source: [Search for cards, boards, and members](https://support.atlassian.com/trello/docs/searching-for-cards-all-boards/).
3. Keyboard shortcuts are a core speed path (board switcher, create card,
   filter, and assignment shortcuts).
   Source: [Using keyboard shortcuts in Trello](https://support.atlassian.com/trello/docs/using-keyboard-shortcuts-in-trello/).
4. Markdown is supported in card descriptions/comments.
   Source: [Using Markdown in Trello](https://support.atlassian.com/trello/docs/using-markdown-in-trello/).

### Views and analytics model

1. Table view supports inline card edits, filtering, and drag reorder (Premium/Enterprise).
   Source: [Table view](https://support.atlassian.com/trello/docs/single-board-table-view/).
2. Dashboard view provides chart tiles by list, due date, member, and label
   (Premium).
   Source: [Dashboard view](https://support.atlassian.com/trello/docs/dashboard-view).
3. Map view supports geospatial card location workflows (Premium).
   Source: [Map view](https://support.atlassian.com/trello/docs/map-view/).
4. Calendar (Power-Up) provides due-date calendar interactions and iCal export.
   Source: [Use the Calendar Power-Up](https://support.atlassian.com/trello/docs/using-the-calendar-power-up/).

### Pricing and plan boundaries

1. Trello pricing differentiates collaboration limits and advanced capability by
   plan tier.
2. Premium/Enterprise access patterns appear across advanced views and features.
   Source: [Trello pricing](https://trello.com/pricing).

## Taskboard V2 Implications

1. Preserve the list/lane and card/ticket mental model with fast move/reorder
   workflows.
2. Add practical metadata depth first (labels, dates, checklist) before adding
   tertiary capabilities.
3. Ship keyboard-driven and filter/search ergonomics early to reduce click cost.
4. Keep premium-style analytics/maps as explicit post-v2 candidates unless AJ
   feature-lock marks them must-have.

## Confidence and Gaps

1. Confidence is high for list/card flow, filtering, metadata, and view
   taxonomy.
2. Confidence is medium for plan-tier nuance because pricing pages are dynamic
   and can change quickly.
3. Publication dates were unavailable in several support pages; retrieval dates
   are tracked instead.

## Related docs

1. [Taskboard Trello Gap Matrix](./taskboard-trello-gap-matrix.md)
2. [Taskboard Trello Image Catalog](./taskboard-trello-image-catalog.md)
3. [Taskboard V2 Initiative Plan](../Plan/taskboard-v2-initiative-plan.md)
