import Foundation

struct LaneEditorDraft: Identifiable {
  enum Mode: Equatable {
    case create
    case edit(laneID: String)
  }

  var mode: Mode
  var title: String
  var templateID: String?
  var hasWIPLimit: Bool
  var wipLimit: Int

  var id: String {
    switch mode {
    case .create:
      return "create-lane"
    case .edit(let laneID):
      return "edit-\(laneID)"
    }
  }

  static func create() -> LaneEditorDraft {
    LaneEditorDraft(
      mode: .create,
      title: "",
      templateID: nil,
      hasWIPLimit: false,
      wipLimit: 1
    )
  }

  static func edit(
    lane: TaskboardLane
  ) -> LaneEditorDraft {
    LaneEditorDraft(
      mode: .edit(laneID: lane.id),
      title: lane.title,
      templateID: lane.templateID,
      hasWIPLimit: lane.wipLimit != nil,
      wipLimit: max(1, lane.wipLimit ?? 1)
    )
  }
}

struct TicketEditorDraft: Identifiable {
  enum Mode: Equatable {
    case create(laneID: String)
    case edit(laneID: String, ticketID: String)

    var isCreate: Bool {
      switch self {
      case .create:
        return true
      case .edit:
        return false
      }
    }
  }

  var mode: Mode
  var title: String
  var owner: String
  var assigneesText: String
  var priority: TaskboardTicketPriority
  var labelsText: String
  var hasDueDate: Bool
  var dueDate: Date
  var checklistItems: [TaskboardChecklistItem]
  var pendingChecklistTitle: String
  var descriptionMarkdown: String
  var comments: [TaskboardComment]
  var pendingCommentAuthor: String
  var pendingCommentBody: String

  var id: String {
    switch mode {
    case .create(let laneID):
      return "new-ticket-\(laneID)"
    case .edit(let laneID, let ticketID):
      return "edit-ticket-\(laneID)-\(ticketID)"
    }
  }

  static func create(
    laneID: String
  ) -> TicketEditorDraft {
    TicketEditorDraft(
      mode: .create(laneID: laneID),
      title: "",
      owner: "",
      assigneesText: "",
      priority: .medium,
      labelsText: "",
      hasDueDate: false,
      dueDate: Date(),
      checklistItems: [],
      pendingChecklistTitle: "",
      descriptionMarkdown: "",
      comments: [],
      pendingCommentAuthor: "",
      pendingCommentBody: ""
    )
  }

  static func edit(
    ticket: TaskboardTicket,
    laneID: String
  ) -> TicketEditorDraft {
    let parsedDueDate = TaskboardDateCoder.date(fromDateOnly: ticket.dueDateISO8601)

    return TicketEditorDraft(
      mode: .edit(laneID: laneID, ticketID: ticket.id),
      title: ticket.title,
      owner: ticket.owner,
      assigneesText: ticket.assignees.map(\.displayName).joined(separator: ", "),
      priority: ticket.priority,
      labelsText: ticket.labels.joined(separator: ", "),
      hasDueDate: parsedDueDate != nil,
      dueDate: parsedDueDate ?? Date(),
      checklistItems: ticket.checklist,
      pendingChecklistTitle: "",
      descriptionMarkdown: ticket.descriptionMarkdown,
      comments: ticket.comments,
      pendingCommentAuthor: "",
      pendingCommentBody: ""
    )
  }
}

struct InlineTicketEditorDraft: Identifiable {
  enum Mode: Equatable {
    case edit(laneID: String, ticketID: String)
  }

  var mode: Mode
  var title: String
  var assigneesText: String
  var labelsText: String

  var id: String {
    switch mode {
    case .edit(let laneID, let ticketID):
      return "\(laneID)::\(ticketID)"
    }
  }

  var laneID: String {
    switch mode {
    case .edit(let laneID, _):
      return laneID
    }
  }

  var ticketID: String {
    switch mode {
    case .edit(_, let ticketID):
      return ticketID
    }
  }

  static func edit(
    ticket: TaskboardTicket,
    laneID: String
  ) -> InlineTicketEditorDraft {
    return InlineTicketEditorDraft(
      mode: .edit(laneID: laneID, ticketID: ticket.id),
      title: ticket.title,
      assigneesText: ticket.assignees.map(\.displayName).joined(separator: ", "),
      labelsText: ticket.labels.joined(separator: ", ")
    )
  }
}

struct PendingTicketDeletion: Identifiable {
  let laneID: String
  let ticketID: String
  let ticketTitle: String

  var id: String {
    "\(laneID)::\(ticketID)"
  }
}
