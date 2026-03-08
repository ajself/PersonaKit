import Foundation
import SwiftUI

extension TaskboardPanelView {
  func ticketCountLabel(
    for lane: TaskboardLane,
    visibleCount: Int
  ) -> String {
    if !isFilteringActive {
      return "\(lane.tickets.count)"
    }

    return "\(visibleCount)/\(lane.tickets.count)"
  }

  func clearFilters() {
    activeLabelFilter = nil
    dueDateFilter = .all
    ownerFilterText = ""
    keywordFilterText = ""
  }

  var keywordSearchResult: TaskboardSearchResult? {
    TaskboardSearchEngine.search(
      board: board,
      query: keywordFilterText
    )
  }

  func filteredTickets(
    in lane: TaskboardLane
  ) -> [TaskboardTicket] {
    let ownerFilter = ownerFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
    let searchResult = keywordSearchResult

    return lane.tickets.filter { ticket in
      if let activeLabelFilter,
        !ticket.labels.contains(where: { $0.caseInsensitiveCompare(activeLabelFilter) == .orderedSame })
      {
        return false
      }

      if !ownerFilter.isEmpty,
        ticket.owner.range(
          of: ownerFilter,
          options: .caseInsensitive
        ) == nil
      {
        return false
      }

      if !matchesDueDateFilter(ticket) {
        return false
      }

      if let searchResult,
        !searchResult.matchingLaneIDs.contains(lane.id),
        !searchResult.matchingTicketIDs.contains(ticket.id)
      {
        return false
      }

      return true
    }
  }

  func matchesDueDateFilter(
    _ ticket: TaskboardTicket
  ) -> Bool {
    switch dueDateFilter {
    case .all:
      return true

    case .withDueDate:
      return parseISODate(ticket.dueDateISO8601) != nil

    case .overdue:
      return TaskboardDateCoder.isOverdue(ticket.dueDateISO8601)

    case .noDueDate:
      return parseISODate(ticket.dueDateISO8601) == nil
    }
  }

  func dueDateText(
    for iso8601Date: String?
  ) -> String? {
    TaskboardDateCoder.displayText(fromDateOnly: iso8601Date)
  }

  func checklistSummary(
    for ticket: TaskboardTicket
  ) -> String {
    let completedCount = ticket.checklist.filter(\.isComplete).count
    return "Checklist \(completedCount)/\(ticket.checklist.count)"
  }

  func parseISODate(
    _ value: String?
  ) -> Date? {
    TaskboardDateCoder.date(fromDateOnly: value)
  }

  func encodeISODate(
    _ date: Date?
  ) -> String? {
    TaskboardDateCoder.encodeDateOnly(from: date)
  }

  func checklistCompletionBinding(
    index: Int,
    fallbackDraft: TicketEditorDraft
  ) -> Binding<Bool> {
    Binding(
      get: {
        let items = ticketEditorDraft?.checklistItems ?? fallbackDraft.checklistItems
        guard items.indices.contains(index) else {
          return false
        }

        return items[index].isComplete
      },
      set: { newValue in
        guard var draft = ticketEditorDraft else {
          return
        }
        guard draft.checklistItems.indices.contains(index) else {
          return
        }

        draft.checklistItems[index].isComplete = newValue
        ticketEditorDraft = draft
      }
    )
  }

  func checklistTitleBinding(
    index: Int,
    fallbackDraft: TicketEditorDraft
  ) -> Binding<String> {
    Binding(
      get: {
        let items = ticketEditorDraft?.checklistItems ?? fallbackDraft.checklistItems
        guard items.indices.contains(index) else {
          return ""
        }

        return items[index].title
      },
      set: { newValue in
        guard var draft = ticketEditorDraft else {
          return
        }
        guard draft.checklistItems.indices.contains(index) else {
          return
        }

        draft.checklistItems[index].title = newValue
        ticketEditorDraft = draft
      }
    )
  }

  func removeChecklistItem(
    at index: Int
  ) {
    guard var draft = ticketEditorDraft else {
      return
    }

    if draft.checklistItems.indices.contains(index) {
      draft.checklistItems.remove(at: index)
      ticketEditorDraft = draft
    }
  }

}
