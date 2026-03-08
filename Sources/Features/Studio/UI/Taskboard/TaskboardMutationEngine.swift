import Foundation

struct TaskboardMutationRequest: Equatable {
  let schemaVersion: Int
  let requestID: String
  let expectedBoardRevision: Int
  let operation: TaskboardMutationOperation
}

enum TaskboardMutationOperation: Equatable {
  case createLane(CreateLanePayload)
  case editLane(EditLanePayload)
  case reorderLane(ReorderLanePayload)
  case deleteLane(DeleteLanePayload)
  case createTicket(CreateTicketPayload)
  case editTicket(EditTicketPayload)
  case moveTicket(MoveTicketPayload)
  case deleteTicket(DeleteTicketPayload)
}

struct CreateLanePayload: Equatable {
  let title: String
  let templateID: String?
  let wipLimit: Int?
  let isCollapsed: Bool
}

struct EditLanePayload: Equatable {
  let laneID: String
  let title: String
  let templateID: String?
  let wipLimit: Int?
  let isCollapsed: Bool
}

struct ReorderLanePayload: Equatable {
  let laneID: String
  let destinationIndex: Int
}

struct DeleteLanePayload: Equatable {
  let laneID: String
}

struct CreateTicketPayload: Equatable {
  let laneID: String
  let title: String
  let owner: String
  let assignees: [TaskboardAssignee]
  let priority: TaskboardTicketPriority
  let labels: [String]
  let dueDateISO8601: String?
  let checklist: [TaskboardChecklistItem]
  let descriptionMarkdown: String
  let comments: [TaskboardComment]
}

struct EditTicketPayload: Equatable {
  let laneID: String
  let ticketID: String
  let title: String
  let owner: String
  let assignees: [TaskboardAssignee]
  let priority: TaskboardTicketPriority
  let labels: [String]
  let dueDateISO8601: String?
  let checklist: [TaskboardChecklistItem]
  let descriptionMarkdown: String
  let comments: [TaskboardComment]
}

struct MoveTicketPayload: Equatable {
  let ticketID: String
  let sourceLaneID: String
  let destinationLaneID: String
  let destinationIndex: Int?
}

struct DeleteTicketPayload: Equatable {
  let laneID: String
  let ticketID: String
}

struct TaskboardMutationResult: Equatable {
  let board: TaskboardBoard
  let boardRevision: Int
  let duplicateRequest: Bool
}

struct TaskboardMutationError: Error, Equatable {
  enum Code: String, Equatable {
    case unsupportedOperation = "unsupported_operation"
    case schemaVersionMismatch = "schema_version_mismatch"
    case revisionConflict = "revision_conflict"
    case laneNotFound = "lane_not_found"
    case ticketNotFound = "ticket_not_found"
    case validationFailed = "validation_failed"
  }

  let code: Code
  let message: String
  let details: [String: String]
}

enum TaskboardMutationEngine {
  static let schemaVersion = 1

  static func apply(
    _ request: TaskboardMutationRequest,
    to board: TaskboardBoard,
    boardRevision: Int,
    processedRequestIDs: Set<String> = []
  ) throws -> TaskboardMutationResult {
    if request.schemaVersion != schemaVersion {
      throw TaskboardMutationError(
        code: .schemaVersionMismatch,
        message: "Unsupported schema version.",
        details: [
          "expectedSchemaVersion": "\(schemaVersion)",
          "actualSchemaVersion": "\(request.schemaVersion)",
        ]
      )
    }

    if processedRequestIDs.contains(request.requestID) {
      return TaskboardMutationResult(
        board: board.normalized(),
        boardRevision: boardRevision,
        duplicateRequest: true
      )
    }

    if request.expectedBoardRevision != boardRevision {
      throw TaskboardMutationError(
        code: .revisionConflict,
        message: "Expected board revision does not match current revision.",
        details: [
          "expectedBoardRevision": "\(request.expectedBoardRevision)",
          "actualBoardRevision": "\(boardRevision)",
        ]
      )
    }

    let normalizedInput = board.normalized()
    let updatedBoard = try mutate(operation: request.operation, board: normalizedInput).normalized()
    return TaskboardMutationResult(
      board: updatedBoard,
      boardRevision: boardRevision + 1,
      duplicateRequest: false
    )
  }

  private static func mutate(
    operation: TaskboardMutationOperation,
    board: TaskboardBoard
  ) throws -> TaskboardBoard {
    var board = board

    switch operation {
    case .createLane(let payload):
      let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else {
        throw validationFailed("Lane title cannot be empty.")
      }

      let lane = TaskboardLane(
        id: "lane-\(board.nextLaneSequence)",
        title: uniqueLaneTitle(baseTitle: title, excludingLaneID: nil, in: board),
        templateID: payload.templateID,
        order: nextLaneOrder(in: board),
        wipLimit: normalizedWIPLimit(payload.wipLimit),
        isCollapsed: payload.isCollapsed,
        tickets: []
      )
      board.nextLaneSequence += 1
      board.lanes.append(lane)

    case .editLane(let payload):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == payload.laneID }) else {
        throw laneNotFound(payload.laneID)
      }

      let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else {
        throw validationFailed("Lane title cannot be empty.")
      }

      board.lanes[laneIndex].title = uniqueLaneTitle(
        baseTitle: title,
        excludingLaneID: payload.laneID,
        in: board
      )
      board.lanes[laneIndex].templateID = payload.templateID
      board.lanes[laneIndex].wipLimit = normalizedWIPLimit(payload.wipLimit)
      board.lanes[laneIndex].isCollapsed = payload.isCollapsed

    case .reorderLane(let payload):
      var lanes = board.lanes.sorted {
        if $0.order == $1.order {
          return $0.id < $1.id
        }
        return $0.order < $1.order
      }
      guard let sourceIndex = lanes.firstIndex(where: { $0.id == payload.laneID }) else {
        throw laneNotFound(payload.laneID)
      }
      guard lanes.indices.contains(payload.destinationIndex) else {
        throw validationFailed("Lane destination index is out of bounds.")
      }

      let lane = lanes.remove(at: sourceIndex)
      lanes.insert(lane, at: payload.destinationIndex)
      for index in lanes.indices {
        lanes[index].order = index + 1
      }
      board.lanes = lanes

    case .deleteLane(let payload):
      guard board.lanes.contains(where: { $0.id == payload.laneID }) else {
        throw laneNotFound(payload.laneID)
      }
      board.lanes.removeAll { $0.id == payload.laneID }

    case .createTicket(let payload):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == payload.laneID }) else {
        throw laneNotFound(payload.laneID)
      }

      let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else {
        throw validationFailed("Ticket title cannot be empty.")
      }

      let owner = payload.owner.trimmingCharacters(in: .whitespacesAndNewlines)
      let assignees = normalizedAssignees(
        payload.assignees,
        fallbackOwner: owner
      )
      let normalizedDueDate = normalizedDueDate(payload.dueDateISO8601)
      let checklist = normalizedChecklist(payload.checklist, nextChecklistSequence: &board.nextChecklistSequence)
      let comments = normalizedComments(payload.comments, nextCommentSequence: &board.nextCommentSequence)

      let ticket = TaskboardTicket(
        id: "ticket-\(board.nextTicketSequence)",
        title: title,
        owner: assignees.first?.displayName ?? (owner.isEmpty ? "Unassigned" : owner),
        assignees: assignees,
        priority: payload.priority,
        labels: normalizedLabels(payload.labels),
        dueDateISO8601: normalizedDueDate,
        checklist: checklist,
        descriptionMarkdown: payload.descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines),
        comments: comments
      )
      board.nextTicketSequence += 1
      board.lanes[laneIndex].tickets.append(ticket)

    case .editTicket(let payload):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == payload.laneID }) else {
        throw laneNotFound(payload.laneID)
      }
      guard let ticketIndex = board.lanes[laneIndex].tickets.firstIndex(where: { $0.id == payload.ticketID }) else {
        throw ticketNotFound(payload.ticketID)
      }

      let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else {
        throw validationFailed("Ticket title cannot be empty.")
      }

      let owner = payload.owner.trimmingCharacters(in: .whitespacesAndNewlines)
      let assignees = normalizedAssignees(
        payload.assignees,
        fallbackOwner: owner
      )
      let normalizedDueDate = normalizedDueDate(payload.dueDateISO8601)
      let checklist = normalizedChecklist(payload.checklist, nextChecklistSequence: &board.nextChecklistSequence)
      let comments = normalizedComments(payload.comments, nextCommentSequence: &board.nextCommentSequence)

      board.lanes[laneIndex].tickets[ticketIndex].title = title
      board.lanes[laneIndex].tickets[ticketIndex].owner =
        assignees.first?.displayName
        ?? (owner.isEmpty ? "Unassigned" : owner)
      board.lanes[laneIndex].tickets[ticketIndex].assignees = assignees
      board.lanes[laneIndex].tickets[ticketIndex].priority = payload.priority
      board.lanes[laneIndex].tickets[ticketIndex].labels = normalizedLabels(payload.labels)
      board.lanes[laneIndex].tickets[ticketIndex].dueDateISO8601 = normalizedDueDate
      board.lanes[laneIndex].tickets[ticketIndex].checklist = checklist
      board.lanes[laneIndex].tickets[ticketIndex].descriptionMarkdown = payload.descriptionMarkdown
        .trimmingCharacters(in: .whitespacesAndNewlines)
      board.lanes[laneIndex].tickets[ticketIndex].comments = comments

    case .moveTicket(let payload):
      guard let sourceLaneIndex = board.lanes.firstIndex(where: { $0.id == payload.sourceLaneID }) else {
        throw laneNotFound(payload.sourceLaneID)
      }
      guard let destinationLaneIndex = board.lanes.firstIndex(where: { $0.id == payload.destinationLaneID }) else {
        throw laneNotFound(payload.destinationLaneID)
      }
      guard let ticketIndex = board.lanes[sourceLaneIndex].tickets.firstIndex(where: { $0.id == payload.ticketID })
      else {
        throw ticketNotFound(payload.ticketID)
      }

      let ticket = board.lanes[sourceLaneIndex].tickets.remove(at: ticketIndex)
      let destinationIndex = payload.destinationIndex ?? board.lanes[destinationLaneIndex].tickets.count
      guard destinationIndex >= 0, destinationIndex <= board.lanes[destinationLaneIndex].tickets.count else {
        throw validationFailed("Ticket destination index is out of bounds.")
      }
      board.lanes[destinationLaneIndex].tickets.insert(ticket, at: destinationIndex)

    case .deleteTicket(let payload):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == payload.laneID }) else {
        throw laneNotFound(payload.laneID)
      }
      let removedCountBefore = board.lanes[laneIndex].tickets.count
      board.lanes[laneIndex].tickets.removeAll { $0.id == payload.ticketID }
      if board.lanes[laneIndex].tickets.count == removedCountBefore {
        throw ticketNotFound(payload.ticketID)
      }
    }

    return board
  }

  private static func validationFailed(
    _ message: String
  ) -> TaskboardMutationError {
    TaskboardMutationError(
      code: .validationFailed,
      message: message,
      details: [:]
    )
  }

  private static func laneNotFound(
    _ laneID: String
  ) -> TaskboardMutationError {
    TaskboardMutationError(
      code: .laneNotFound,
      message: "Lane not found.",
      details: [
        "laneID": laneID
      ]
    )
  }

  private static func ticketNotFound(
    _ ticketID: String
  ) -> TaskboardMutationError {
    TaskboardMutationError(
      code: .ticketNotFound,
      message: "Ticket not found.",
      details: [
        "ticketID": ticketID
      ]
    )
  }

  private static func normalizedLabels(
    _ labels: [String]
  ) -> [String] {
    Array(
      Set(
        labels
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      )
    )
    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  private static func normalizedDueDate(
    _ value: String?
  ) -> String? {
    guard TaskboardDateCoder.parseDateOnly(value) != nil else {
      return nil
    }
    return value
  }

  private static func normalizedWIPLimit(
    _ value: Int?
  ) -> Int? {
    guard let value else {
      return nil
    }

    return value > 0 ? value : nil
  }

  private static func normalizedAssignees(
    _ assignees: [TaskboardAssignee],
    fallbackOwner: String
  ) -> [TaskboardAssignee] {
    let normalized =
      assignees
      .map { assignee in
        let displayName = assignee.displayName
          .trimmingCharacters(in: .whitespacesAndNewlines)
        return TaskboardAssignee(
          id: TaskboardMemberCoder.memberID(from: displayName),
          displayName: displayName
        )
      }
      .filter { !$0.displayName.isEmpty }

    if !normalized.isEmpty {
      return Array(
        Dictionary(
          grouping: normalized,
          by: \.id
        )
        .values
        .compactMap(\.first)
      )
      .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    let owner = fallbackOwner.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !owner.isEmpty else {
      return []
    }

    return [
      TaskboardAssignee(
        id: TaskboardMemberCoder.memberID(from: owner),
        displayName: owner
      )
    ]
  }

  private static func normalizedChecklist(
    _ checklist: [TaskboardChecklistItem],
    nextChecklistSequence: inout Int
  ) -> [TaskboardChecklistItem] {
    checklist.compactMap { item in
      let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else {
        return nil
      }

      var normalizedItem = item
      normalizedItem.title = title
      if !normalizedItem.id.hasPrefix("check-") {
        normalizedItem.id = "check-\(nextChecklistSequence)"
        nextChecklistSequence += 1
      }
      return normalizedItem
    }
  }

  private static func normalizedComments(
    _ comments: [TaskboardComment],
    nextCommentSequence: inout Int
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
        normalizedComment.id = "comment-\(nextCommentSequence)"
        nextCommentSequence += 1
      }

      return normalizedComment
    }
  }

  private static func uniqueLaneTitle(
    baseTitle: String,
    excludingLaneID: String?,
    in board: TaskboardBoard
  ) -> String {
    let existingTitles = Set(
      board.lanes.compactMap { lane -> String? in
        if lane.id == excludingLaneID {
          return nil
        }
        return lane.title.lowercased()
      }
    )

    if !existingTitles.contains(baseTitle.lowercased()) {
      return baseTitle
    }

    var suffix = 2
    while true {
      let candidate = "\(baseTitle) \(suffix)"
      if !existingTitles.contains(candidate.lowercased()) {
        return candidate
      }
      suffix += 1
    }
  }

  private static func nextLaneOrder(
    in board: TaskboardBoard
  ) -> Int {
    (board.lanes.map(\.order).max() ?? 0) + 1
  }
}
