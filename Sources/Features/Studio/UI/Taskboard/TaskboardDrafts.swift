import Foundation

struct LaneEditorDraft: Identifiable {
  enum Mode: Equatable {
    case create
    case edit(laneID: String)
  }

  var mode: Mode
  var title: String
  var templateID: String?

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
      templateID: nil
    )
  }

  static func edit(
    lane: TaskboardLane
  ) -> LaneEditorDraft {
    LaneEditorDraft(
      mode: .edit(laneID: lane.id),
      title: lane.title,
      templateID: lane.templateID
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
  var priority: TaskboardTicketPriority
  var labelsText: String
  var hasDueDate: Bool
  var dueDate: Date
  var checklistItems: [TaskboardChecklistItem]
  var pendingChecklistTitle: String

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
      priority: .medium,
      labelsText: "",
      hasDueDate: false,
      dueDate: Date(),
      checklistItems: [],
      pendingChecklistTitle: ""
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
      priority: ticket.priority,
      labelsText: ticket.labels.joined(separator: ", "),
      hasDueDate: parsedDueDate != nil,
      dueDate: parsedDueDate ?? Date(),
      checklistItems: ticket.checklist,
      pendingChecklistTitle: ""
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
