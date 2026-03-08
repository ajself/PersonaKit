import Foundation
import SwiftUI

extension TaskboardPanelView {
  func createLane(
    from template: TaskboardLaneTemplate
  ) {
    let title = uniqueLaneTitle(
      baseTitle: template.title,
      excludingLaneID: nil
    )

    let lane = TaskboardLane(
      id: nextLaneID(),
      title: title,
      templateID: template.id,
      order: nextLaneOrder(),
      tickets: []
    )
    board.lanes.append(lane)
    selectedLaneID = lane.id
  }

  func openTicketComposerForSelectedLane() {
    guard let selectedLaneID else {
      return
    }

    ticketEditorDraft = TicketEditorDraft.create(laneID: selectedLaneID)
  }

  func editSelectedLane() {
    guard
      let selectedLaneID,
      let lane = board.lanes.first(where: { $0.id == selectedLaneID })
    else {
      return
    }

    laneEditorDraft = LaneEditorDraft.edit(lane: lane)
  }

  func selectAdjacentLane(
    direction: Int
  ) {
    selectedLaneID = TaskboardLaneNavigation.adjacentLaneID(
      lanes: sortedLanes,
      selectedLaneID: selectedLaneID,
      direction: direction
    )
  }

  func focusKeywordSearch() {
    focusedField = .keywordSearch
  }

  func ticketDragPayload(
    ticketID: String,
    laneID: String
  ) -> String {
    "ticket|\(ticketID)|\(laneID)"
  }

  func parseTicketDragPayload(
    _ payload: String
  ) -> (ticketID: String, sourceLaneID: String)? {
    let components = payload.split(separator: "|", omittingEmptySubsequences: false)

    guard
      components.count == 3,
      components[0] == "ticket"
    else {
      return nil
    }

    return (
      ticketID: String(components[1]),
      sourceLaneID: String(components[2])
    )
  }

  func handleTicketDrop(
    _ payloads: [String],
    destinationLaneID: String
  ) -> Bool {
    guard let firstPayload = payloads.first,
      let parsed = parseTicketDragPayload(firstPayload)
    else {
      return false
    }

    guard parsed.sourceLaneID != destinationLaneID else {
      return false
    }

    moveTicket(
      ticketID: parsed.ticketID,
      fromLaneID: parsed.sourceLaneID,
      toLaneID: destinationLaneID
    )
    selectedLaneID = destinationLaneID
    activeDropLaneID = nil
    return true
  }

  func laneOutlineColor(
    for laneID: String
  ) -> Color {
    if activeDropLaneID == laneID {
      return .accentColor
    }

    if selectedLaneID == laneID {
      return .accentColor
    }

    return .clear
  }

  func addChecklistItem() {
    guard var draft = ticketEditorDraft else {
      return
    }

    let trimmedTitle = draft.pendingChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      return
    }

    draft.checklistItems.append(
      TaskboardChecklistItem(
        id: "draft-check-\(draft.checklistItems.count + 1)",
        title: trimmedTitle,
        isComplete: false
      )
    )
    draft.pendingChecklistTitle = ""
    ticketEditorDraft = draft
  }

  func resetBoard() {
    board = TaskboardBoard.defaultBoard
    selectedLaneID = board.lanes
      .sorted { $0.order < $1.order }
      .first?
      .id
    persistenceMessage = "Taskboard reset to default lanes."
    persistenceIsError = false
  }

  func moveLane(
    laneID: String,
    direction: Int
  ) {
    var lanes = sortedLanes

    guard let currentIndex = lanes.firstIndex(where: { $0.id == laneID }) else {
      return
    }

    let targetIndex = currentIndex + direction

    guard lanes.indices.contains(targetIndex) else {
      return
    }

    lanes.swapAt(currentIndex, targetIndex)

    for index in lanes.indices {
      lanes[index].order = index + 1
    }

    board.lanes = lanes
  }

  func deleteLane(
    laneID: String
  ) {
    board.lanes.removeAll {
      $0.id == laneID
    }
    if selectedLaneID == laneID {
      selectedLaneID = board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
    }
    pendingLaneDeletion = nil
  }

  func applyLaneEditorDraft() {
    guard var draft = laneEditorDraft else {
      return
    }

    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !draft.title.isEmpty else {
      return
    }

    switch draft.mode {
    case .create:
      let lane = TaskboardLane(
        id: nextLaneID(),
        title: uniqueLaneTitle(baseTitle: draft.title, excludingLaneID: nil),
        templateID: draft.templateID,
        order: nextLaneOrder(),
        tickets: []
      )
      board.lanes.append(lane)
      selectedLaneID = lane.id

    case .edit(let laneID):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
        laneEditorDraft = nil
        return
      }

      board.lanes[laneIndex].title = uniqueLaneTitle(
        baseTitle: draft.title,
        excludingLaneID: laneID
      )
      board.lanes[laneIndex].templateID = draft.templateID
      selectedLaneID = laneID
    }

    laneEditorDraft = nil
  }

  func applyTicketEditorDraft() {
    guard var draft = ticketEditorDraft else {
      return
    }

    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.owner = draft.owner.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.labelsText = draft.labelsText.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.pendingChecklistTitle = draft.pendingChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.checklistItems = draft.checklistItems
      .map { item in
        var normalizedItem = item
        normalizedItem.title = normalizedItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedItem
      }
      .filter { !$0.title.isEmpty }

    guard !draft.title.isEmpty else {
      return
    }

    let owner = draft.owner.isEmpty ? "Unassigned" : draft.owner
    let labels = parsedLabels(from: draft.labelsText)
    let dueDateISO8601 = draft.hasDueDate
      ? encodeISODate(draft.dueDate)
      : nil
    let checklistItems = normalizedChecklistItems(from: draft.checklistItems)

    switch draft.mode {
    case .create(let laneID):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
        ticketEditorDraft = nil
        return
      }

      board.lanes[laneIndex].tickets.append(
        TaskboardTicket(
          id: nextTicketID(),
          title: draft.title,
          owner: owner,
          priority: draft.priority,
          labels: labels,
          dueDateISO8601: dueDateISO8601,
          checklist: checklistItems
        )
      )

    case .edit(let laneID, let ticketID):
      guard
        let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }),
        let ticketIndex = board.lanes[laneIndex].tickets.firstIndex(where: { $0.id == ticketID })
      else {
        ticketEditorDraft = nil
        return
      }

      board.lanes[laneIndex].tickets[ticketIndex].title = draft.title
      board.lanes[laneIndex].tickets[ticketIndex].owner = owner
      board.lanes[laneIndex].tickets[ticketIndex].priority = draft.priority
      board.lanes[laneIndex].tickets[ticketIndex].labels = labels
      board.lanes[laneIndex].tickets[ticketIndex].dueDateISO8601 = dueDateISO8601
      board.lanes[laneIndex].tickets[ticketIndex].checklist = checklistItems
    }

    ticketEditorDraft = nil
  }

  func parsedLabels(
    from value: String
  ) -> [String] {
    Array(
      Set(
        value
          .split(separator: ",", omittingEmptySubsequences: true)
          .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      )
    )
    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  func normalizedChecklistItems(
    from items: [TaskboardChecklistItem]
  ) -> [TaskboardChecklistItem] {
    items.enumerated().map { index, item in
      var normalizedItem = item
      if !normalizedItem.id.hasPrefix("check-") {
        normalizedItem.id = nextChecklistItemID()
      }
      normalizedItem.title = normalizedItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
      if normalizedItem.title.isEmpty {
        normalizedItem.title = "Checklist Item \(index + 1)"
      }
      return normalizedItem
    }
  }

  func laneDestinations(
    excludingLaneID: String
  ) -> [TaskboardLane] {
    sortedLanes.filter {
      $0.id != excludingLaneID
    }
  }

  func moveTicketRelative(
    ticketID: String,
    fromLaneID: String,
    direction: Int
  ) {
    let laneIDs = sortedLanes.map(\.id)

    guard let laneIndex = laneIDs.firstIndex(of: fromLaneID) else {
      return
    }

    let targetIndex = laneIndex + direction

    guard laneIDs.indices.contains(targetIndex) else {
      return
    }

    moveTicket(
      ticketID: ticketID,
      fromLaneID: fromLaneID,
      toLaneID: laneIDs[targetIndex]
    )
  }

  func moveTicket(
    ticketID: String,
    fromLaneID: String,
    toLaneID: String
  ) {
    guard fromLaneID != toLaneID else {
      return
    }

    guard
      let sourceLaneIndex = board.lanes.firstIndex(where: { $0.id == fromLaneID }),
      let ticketIndex = board.lanes[sourceLaneIndex].tickets.firstIndex(where: { $0.id == ticketID }),
      let destinationLaneIndex = board.lanes.firstIndex(where: { $0.id == toLaneID })
    else {
      return
    }

    let ticket = board.lanes[sourceLaneIndex].tickets.remove(at: ticketIndex)
    board.lanes[destinationLaneIndex].tickets.append(ticket)
    selectedLaneID = toLaneID
  }

  func deleteTicket(
    ticketID: String,
    laneID: String
  ) {
    guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
      pendingTicketDeletion = nil
      return
    }

    board.lanes[laneIndex].tickets.removeAll {
      $0.id == ticketID
    }
    pendingTicketDeletion = nil
  }

  func uniqueLaneTitle(
    baseTitle: String,
    excludingLaneID: String?
  ) -> String {
    let normalizedBase = baseTitle.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedBase.isEmpty else {
      return "New Lane"
    }

    let existingTitles = Set(
      board.lanes.compactMap { lane -> String? in
        if lane.id == excludingLaneID {
          return nil
        }

        return lane.title.lowercased()
      }
    )

    if !existingTitles.contains(normalizedBase.lowercased()) {
      return normalizedBase
    }

    var suffix = 2

    while true {
      let candidate = "\(normalizedBase) \(suffix)"

      if !existingTitles.contains(candidate.lowercased()) {
        return candidate
      }

      suffix += 1
    }
  }

  func nextLaneID() -> String {
    let id = "lane-\(board.nextLaneSequence)"
    board.nextLaneSequence += 1
    return id
  }

  func nextTicketID() -> String {
    let id = "ticket-\(board.nextTicketSequence)"
    board.nextTicketSequence += 1
    return id
  }

  func nextChecklistItemID() -> String {
    let id = "check-\(board.nextChecklistSequence)"
    board.nextChecklistSequence += 1
    return id
  }

  func nextLaneOrder() -> Int {
    (board.lanes.map(\.order).max() ?? 0) + 1
  }

}
