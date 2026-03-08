# Taskboard Trello Gap Matrix

Status: Draft  
Owner: AJ  
Last Reviewed: 2026-03-07

## Purpose

Compare current Taskboard behavior to Trello baseline behaviors and rank the
next decisions for AJ feature lock.

## Scale

1. `Coverage`: `Full`, `Partial`, `None`.
2. `Priority recommendation`:
   - `Must` (v2 lock candidate)
   - `Should` (v2.1)
   - `Later` (defer)

## Matrix

| Capability | Trello baseline | Taskboard v1 status | Coverage | Priority recommendation | Source |
| --- | --- | --- | --- | --- | --- |
| Lane/list model | Lists are board columns and reorderable. | Lanes exist and can move left/right. | Full | Keep | [Move cards or lists](https://support.atlassian.com/trello/docs/moving-cards-or-lists/) |
| Ticket/card create and move | Cards are created in lists and moved across lists. | Tickets can be created and moved across lanes, including drag/drop. | Full | Keep | [Add a card to a board](https://support.atlassian.com/trello/docs/adding-cards-to-a-board/) |
| Card metadata: labels | Labels are first-class metadata/filter dimension. | No label model in ticket. | None | Must | [Create and manage labels](https://support.atlassian.com/trello/docs/creating-and-managing-labels/) |
| Card metadata: checklist | Checklists support task decomposition and advanced checklist capability. | No checklist model. | None | Must | [Add checklists to cards and advanced checklists](https://support.atlassian.com/trello/docs/adding-checklists-to-cards-and-advanced-checklists/) |
| Card metadata: due/start date | Cards support due/start dates and completion state. | No due/start date model. | None | Must | [Add a due date or start date to a card](https://support.atlassian.com/trello/docs/adding-dates-to-cards/) |
| Card metadata: owner/member | Cards support assignment to members. | Single free-text owner exists. | Partial | Should | [Add a person to a card](https://support.atlassian.com/trello/docs/adding-a-member-to-a-card/) |
| Card metadata: custom fields | Custom fields available with plan limits. | No custom field system. | None | Later | [Custom fields](https://support.atlassian.com/trello/docs/custom-fields/) |
| Board filter panel | Filtering by labels/members/dates/keywords. | No filter controls. | None | Must | [Filtering for cards on a board](https://support.atlassian.com/trello/docs/filtering-for-cards-on-a-board/) |
| Global search | Search spans cards and boards. | No search UI/API. | None | Should | [Search for cards, boards, and members](https://support.atlassian.com/trello/docs/searching-for-cards-all-boards/) |
| Keyboard speed paths | Shortcut-first usage is documented and broad. | Limited shortcuts; no board-level quick actions parity. | Partial | Must | [Using keyboard shortcuts in Trello](https://support.atlassian.com/trello/docs/using-keyboard-shortcuts-in-trello/) |
| Markdown in detail text | Markdown is supported in card descriptions/comments. | No description/comments yet. | None | Should | [Using Markdown in Trello](https://support.atlassian.com/trello/docs/using-markdown-in-trello/) |
| Table view | Grid representation with inline edit/filter/reorder. | Board-only lane columns. | None | Later | [Table view](https://support.atlassian.com/trello/docs/single-board-table-view/) |
| Dashboard view | Analytics widgets by list/due/member/label. | No analytics widgets. | None | Later | [Dashboard view](https://support.atlassian.com/trello/docs/dashboard-view) |
| Map view | Location-based board visualization. | No location model. | None | Later | [Map view](https://support.atlassian.com/trello/docs/map-view/) |
| Calendar interactions | Calendar timeline with drag/date adjustment and iCal sync path. | No calendar representation. | None | Later | [Use the Calendar Power-Up](https://support.atlassian.com/trello/docs/using-the-calendar-power-up/) |

## Proposed AJ feature-lock candidate set

### Must (recommended for Taskboard v2)

1. Labels
2. Checklist
3. Due date
4. Board filtering
5. Keyboard speed actions

### Should (recommended for Taskboard v2.1)

1. Search
2. Rich owner assignment model
3. Markdown description and comments

### Later (defer unless AJ elevates)

1. Table view
2. Dashboard view
3. Map view
4. Calendar view
5. Custom fields

## Risk notes

1. The largest usability gap is the lack of filtering/search and ticket depth.
2. Current Taskboard has strong lane CRUD foundations but low throughput at
   moderate ticket volume.
3. Premium-style views are likely distractors before core ticket depth is fixed.

## Related docs

1. [Taskboard Trello Benchmark](./taskboard-trello-benchmark.md)
2. [Taskboard Trello Image Catalog](./taskboard-trello-image-catalog.md)
3. [Taskboard V2 Feature Lock](../Plan/taskboard-v2-feature-lock.md)
