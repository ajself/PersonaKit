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
      wipLimit: nil,
      isCollapsed: false,
      tickets: []
    )
    board.lanes.append(lane)
    selectedLaneID = lane.id
    recordInteractionEvent(
      .createLane,
      details: [
        "laneID": lane.id,
        "templateID": lane.templateID ?? "none",
      ]
    )
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
    destinationLaneID: String,
    destinationTicketID: String? = nil
  ) -> Bool {
    defer {
      activeDropLaneID = nil
      activeDropTicketID = nil
    }

    guard let firstPayload = payloads.first,
      let parsed = parseTicketDragPayload(firstPayload)
    else {
      return false
    }

    guard
      let sourceLaneIndex = board.lanes.firstIndex(where: { $0.id == parsed.sourceLaneID }),
      board.lanes[sourceLaneIndex].tickets.contains(where: { $0.id == parsed.ticketID })
    else {
      return false
    }

    var destinationIndex: Int?
    if let destinationTicketID {
      guard
        let destinationLaneIndex = board.lanes.firstIndex(where: { $0.id == destinationLaneID }),
        let insertionIndex = board.lanes[destinationLaneIndex].tickets.firstIndex(where: {
          $0.id == destinationTicketID
        })
      else {
        return false
      }

      destinationIndex = insertionIndex
    }

    if parsed.sourceLaneID == destinationLaneID {
      guard let destinationIndex else {
        return false
      }

      moveTicketWithinLane(
        ticketID: parsed.ticketID,
        laneID: destinationLaneID,
        toIndex: destinationIndex
      )
    } else {
      moveTicket(
        ticketID: parsed.ticketID,
        fromLaneID: parsed.sourceLaneID,
        toLaneID: destinationLaneID,
        destinationIndex: destinationIndex
      )
    }

    selectedLaneID = destinationLaneID
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
    selectedLaneID =
      board.lanes
      .sorted { $0.order < $1.order }
      .first?
      .id
    persistenceMessage = "Taskboard reset to default lanes."
    persistenceIsError = false
    recordInteractionEvent(.reorderLane, details: ["action": "reset_board"])
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
    recordInteractionEvent(
      .reorderLane,
      details: [
        "laneID": laneID,
        "direction": "\(direction)",
      ]
    )
  }

  func toggleLaneCollapsed(
    laneID: String
  ) {
    guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
      return
    }

    board.lanes[laneIndex].isCollapsed.toggle()
    recordInteractionEvent(
      board.lanes[laneIndex].isCollapsed ? .collapseLane : .expandLane,
      details: ["laneID": laneID]
    )
  }

  func deleteLane(
    laneID: String
  ) {
    board.lanes.removeAll {
      $0.id == laneID
    }
    if selectedLaneID == laneID {
      selectedLaneID =
        board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
    }
    pendingLaneDeletion = nil
    recordInteractionEvent(.deleteLane, details: ["laneID": laneID])
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
        wipLimit: draft.hasWIPLimit ? max(1, draft.wipLimit) : nil,
        isCollapsed: false,
        tickets: []
      )
      board.lanes.append(lane)
      selectedLaneID = lane.id
      recordInteractionEvent(
        .createLane,
        details: [
          "laneID": lane.id,
          "wipLimit": lane.wipLimit.map(String.init) ?? "none",
        ]
      )

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
      board.lanes[laneIndex].wipLimit = draft.hasWIPLimit ? max(1, draft.wipLimit) : nil
      selectedLaneID = laneID
      recordInteractionEvent(
        .editLane,
        details: [
          "laneID": laneID,
          "wipLimit": board.lanes[laneIndex].wipLimit.map(String.init) ?? "none",
        ]
      )
    }

    laneEditorDraft = nil
  }

  func applyTicketEditorDraft() {
    guard var draft = ticketEditorDraft else {
      return
    }

    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.owner = draft.owner.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.assigneesText = draft.assigneesText.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.labelsText = draft.labelsText.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.pendingChecklistTitle = draft.pendingChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.descriptionMarkdown = draft.descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.pendingCommentAuthor = draft.pendingCommentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.pendingCommentBody = draft.pendingCommentBody.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.checklistItems = draft.checklistItems
      .map { item in
        var normalizedItem = item
        normalizedItem.title = normalizedItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedItem
      }
      .filter { !$0.title.isEmpty }
    draft.comments = draft.comments
      .map { comment in
        var normalizedComment = comment
        normalizedComment.author = normalizedComment.author.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedComment.bodyMarkdown = normalizedComment.bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedComment
      }
      .filter { !$0.bodyMarkdown.isEmpty }

    guard !draft.title.isEmpty else {
      return
    }

    let assignees = parsedAssignees(from: draft.assigneesText)
    let owner =
      assignees.first?.displayName
      ?? (draft.owner.isEmpty ? "Unassigned" : draft.owner)
    let labels = parsedLabels(from: draft.labelsText)
    let dueDateISO8601 =
      draft.hasDueDate
      ? encodeISODate(draft.dueDate)
      : nil
    let checklistItems = normalizedChecklistItems(from: draft.checklistItems)
    let comments = normalizedComments(from: draft.comments)

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
          assignees: assignees,
          priority: draft.priority,
          labels: labels,
          dueDateISO8601: dueDateISO8601,
          checklist: checklistItems,
          descriptionMarkdown: draft.descriptionMarkdown,
          comments: comments
        )
      )
      if let ticketID = board.lanes[laneIndex].tickets.last?.id {
        recordInteractionEvent(
          .createTicket,
          details: [
            "laneID": laneID,
            "ticketID": ticketID,
          ]
        )
      }

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
      board.lanes[laneIndex].tickets[ticketIndex].assignees = assignees
      board.lanes[laneIndex].tickets[ticketIndex].priority = draft.priority
      board.lanes[laneIndex].tickets[ticketIndex].labels = labels
      board.lanes[laneIndex].tickets[ticketIndex].dueDateISO8601 = dueDateISO8601
      board.lanes[laneIndex].tickets[ticketIndex].checklist = checklistItems
      board.lanes[laneIndex].tickets[ticketIndex].descriptionMarkdown = draft.descriptionMarkdown
      board.lanes[laneIndex].tickets[ticketIndex].comments = comments
      recordInteractionEvent(
        .editTicket,
        details: [
          "laneID": laneID,
          "ticketID": ticketID,
        ]
      )
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

  func parsedAssignees(
    from value: String
  ) -> [TaskboardAssignee] {
    Array(
      Set(
        value
          .split(separator: ",", omittingEmptySubsequences: true)
          .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      )
    )
    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    .map { displayName in
      TaskboardAssignee(
        id: TaskboardMemberCoder.memberID(from: displayName),
        displayName: displayName
      )
    }
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

  func normalizedComments(
    from comments: [TaskboardComment]
  ) -> [TaskboardComment] {
    comments.compactMap { comment in
      var normalizedComment = comment
      normalizedComment.author = normalizedComment.author
        .trimmingCharacters(in: .whitespacesAndNewlines)
      normalizedComment.bodyMarkdown = normalizedComment.bodyMarkdown
        .trimmingCharacters(in: .whitespacesAndNewlines)

      guard !normalizedComment.bodyMarkdown.isEmpty else {
        return nil
      }

      if normalizedComment.author.isEmpty {
        normalizedComment.author = "Unassigned"
      }

      if !normalizedComment.id.hasPrefix("comment-") {
        normalizedComment.id = nextCommentID()
      }

      return normalizedComment
    }
  }

  func addCommentToDraft() {
    guard var draft = ticketEditorDraft else {
      return
    }

    let author = draft.pendingCommentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
    let body = draft.pendingCommentBody.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !body.isEmpty else {
      return
    }

    draft.comments.append(
      TaskboardComment(
        id: "draft-comment-\(draft.comments.count + 1)",
        author: author.isEmpty ? "Unassigned" : author,
        bodyMarkdown: body
      )
    )
    draft.pendingCommentAuthor = ""
    draft.pendingCommentBody = ""
    ticketEditorDraft = draft
  }

  func removeCommentFromDraft(
    at index: Int
  ) {
    guard var draft = ticketEditorDraft else {
      return
    }

    guard draft.comments.indices.contains(index) else {
      return
    }

    draft.comments.remove(at: index)
    ticketEditorDraft = draft
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
    guard
      let targetLaneID = ticketAdjacentLaneID(
        fromLaneID: fromLaneID,
        direction: direction
      )
    else {
      return
    }

    moveTicket(
      ticketID: ticketID,
      fromLaneID: fromLaneID,
      toLaneID: targetLaneID
    )
  }

  func moveTicketWithinLane(
    ticketID: String,
    laneID: String,
    direction: Int
  ) {
    guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
      return
    }

    guard let ticketIndex = board.lanes[laneIndex].tickets.firstIndex(where: { $0.id == ticketID }) else {
      return
    }

    let destinationIndex = ticketIndex + direction
    guard board.lanes[laneIndex].tickets.indices.contains(destinationIndex) else {
      return
    }

    moveTicketWithinLane(
      ticketID: ticketID,
      laneID: laneID,
      toIndex: destinationIndex
    )
  }

  func moveTicketWithinLane(
    ticketID: String,
    laneID: String,
    toIndex: Int
  ) {
    guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
      return
    }

    guard let sourceIndex = board.lanes[laneIndex].tickets.firstIndex(where: { $0.id == ticketID }) else {
      return
    }

    guard board.lanes[laneIndex].tickets.indices.contains(toIndex) else {
      return
    }

    let adjustedDestinationIndex: Int
    if sourceIndex < toIndex {
      adjustedDestinationIndex = toIndex - 1
    } else {
      adjustedDestinationIndex = toIndex
    }

    guard sourceIndex != adjustedDestinationIndex else {
      return
    }

    let ticket = board.lanes[laneIndex].tickets.remove(at: sourceIndex)
    board.lanes[laneIndex].tickets.insert(ticket, at: adjustedDestinationIndex)
    selectedLaneID = laneID
    recordInteractionEvent(
      .reorderTicket,
      details: [
        "destinationIndex": "\(adjustedDestinationIndex)",
        "laneID": laneID,
        "sourceIndex": "\(sourceIndex)",
        "ticketID": ticketID,
      ]
    )
  }

  func moveTicketToNextLane(
    ticketID: String,
    fromLaneID: String
  ) {
    guard
      let nextLaneID = ticketAdjacentLaneID(
        fromLaneID: fromLaneID,
        direction: 1
      )
    else {
      return
    }

    moveTicket(
      ticketID: ticketID,
      fromLaneID: fromLaneID,
      toLaneID: nextLaneID
    )
  }

  func moveTicketToPreviousLane(
    ticketID: String,
    fromLaneID: String
  ) {
    guard
      let previousLaneID = ticketAdjacentLaneID(
        fromLaneID: fromLaneID,
        direction: -1
      )
    else {
      return
    }

    moveTicket(
      ticketID: ticketID,
      fromLaneID: fromLaneID,
      toLaneID: previousLaneID
    )
  }

  func canMoveTicketWithinLane(
    ticketID: String,
    laneID: String,
    direction: Int
  ) -> Bool {
    guard let lane = board.lanes.first(where: { $0.id == laneID }) else {
      return false
    }

    guard let ticketIndex = lane.tickets.firstIndex(where: { $0.id == ticketID }) else {
      return false
    }

    let destinationIndex = ticketIndex + direction
    return lane.tickets.indices.contains(destinationIndex)
  }

  func canMoveTicketBetweenLanes(
    fromLaneID: String,
    direction: Int
  ) -> Bool {
    ticketAdjacentLaneID(
      fromLaneID: fromLaneID,
      direction: direction
    ) != nil
  }

  func ticketAdjacentLaneID(
    fromLaneID: String,
    direction: Int
  ) -> String? {
    TaskboardTicketLaneNavigation.adjacentLaneID(
      lanes: sortedLanes,
      currentLaneID: fromLaneID,
      direction: direction
    )
  }

  func moveTicket(
    ticketID: String,
    fromLaneID: String,
    toLaneID: String,
    destinationIndex: Int? = nil
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
    let insertIndex = min(
      max(destinationIndex ?? board.lanes[destinationLaneIndex].tickets.count, 0),
      board.lanes[destinationLaneIndex].tickets.count
    )
    board.lanes[destinationLaneIndex].tickets.insert(ticket, at: insertIndex)
    selectedLaneID = toLaneID
    recordInteractionEvent(
      .moveTicket,
      details: [
        "ticketID": ticketID,
        "fromLaneID": fromLaneID,
        "toLaneID": toLaneID,
      ]
    )
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
    recordInteractionEvent(
      .deleteTicket,
      details: [
        "laneID": laneID,
        "ticketID": ticketID,
      ]
    )
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

  func nextCommentID() -> String {
    let id = "comment-\(board.nextCommentSequence)"
    board.nextCommentSequence += 1
    return id
  }

  func nextLaneOrder() -> Int {
    (board.lanes.map(\.order).max() ?? 0) + 1
  }

}
