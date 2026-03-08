import Foundation

struct TaskboardBoard: Codable, Equatable {
  var name: String
  var nextLaneSequence: Int
  var nextTicketSequence: Int
  var nextChecklistSequence: Int
  var nextCommentSequence: Int
  var lanes: [TaskboardLane]

  private enum CodingKeys: String, CodingKey {
    case name
    case nextLaneSequence
    case nextTicketSequence
    case nextChecklistSequence
    case nextCommentSequence
    case lanes
  }

  static let defaultBoard = TaskboardBoard(
    name: "Taskboard",
    nextLaneSequence: 7,
    nextTicketSequence: 4,
    nextChecklistSequence: 3,
    nextCommentSequence: 2,
    lanes: [
      TaskboardLane(
        id: "lane-1",
        title: "Inbox",
        templateID: "inbox",
        order: 1,
        wipLimit: nil,
        isCollapsed: false,
        tickets: []
      ),
      TaskboardLane(
        id: "lane-2",
        title: "Ready",
        templateID: "ready",
        order: 2,
        wipLimit: nil,
        isCollapsed: false,
        tickets: []
      ),
      TaskboardLane(
        id: "lane-3",
        title: "In Progress",
        templateID: "in-progress",
        order: 3,
        wipLimit: 3,
        isCollapsed: false,
        tickets: [
          TaskboardTicket(
            id: "ticket-1",
            title: "Implement Taskboard lane CRUD",
            owner: "Samwise",
            assignees: [
              TaskboardAssignee(
                id: "member-samwise",
                displayName: "Samwise"
              )
            ],
            priority: .high,
            labels: ["taskboard", "ui"],
            dueDateISO8601: "2026-03-12",
            checklist: [
              TaskboardChecklistItem(
                id: "check-1",
                title: "Wire lane actions",
                isComplete: true
              ),
              TaskboardChecklistItem(
                id: "check-2",
                title: "Validate drag and drop",
                isComplete: false
              ),
            ],
            descriptionMarkdown: "Core lane CRUD and movement interactions for the planning surface.",
            comments: [
              TaskboardComment(
                id: "comment-1",
                author: "AJ",
                bodyMarkdown: "M2 baseline is good. Keep pushing toward Trello-level workflow speed."
              )
            ]
          )
        ]
      ),
      TaskboardLane(
        id: "lane-4",
        title: "Blocked",
        templateID: "blocked",
        order: 4,
        wipLimit: nil,
        isCollapsed: false,
        tickets: []
      ),
      TaskboardLane(
        id: "lane-5",
        title: "Review",
        templateID: "review",
        order: 5,
        wipLimit: 2,
        isCollapsed: false,
        tickets: [
          TaskboardTicket(
            id: "ticket-2",
            title: "Run red-pen interaction review",
            owner: "studio-interaction-quality-lead",
            assignees: [
              TaskboardAssignee(
                id: "member-studio-interaction-quality-lead",
                displayName: "studio-interaction-quality-lead"
              )
            ],
            priority: .medium,
            labels: ["quality"],
            dueDateISO8601: nil,
            checklist: [],
            descriptionMarkdown: "Evaluate interaction quality against parity rubric and log findings.",
            comments: []
          )
        ]
      ),
      TaskboardLane(
        id: "lane-6",
        title: "Done",
        templateID: "done",
        order: 6,
        wipLimit: nil,
        isCollapsed: false,
        tickets: [
          TaskboardTicket(
            id: "ticket-3",
            title: "Approve Taskboard feature name",
            owner: "AJ",
            assignees: [
              TaskboardAssignee(
                id: "member-aj",
                displayName: "AJ"
              )
            ],
            priority: .low,
            labels: ["planning"],
            dueDateISO8601: nil,
            checklist: [],
            descriptionMarkdown: "Feature naming checkpoint completed.",
            comments: []
          )
        ]
      ),
    ]
  )

  init(
    name: String,
    nextLaneSequence: Int,
    nextTicketSequence: Int,
    nextChecklistSequence: Int,
    nextCommentSequence: Int,
    lanes: [TaskboardLane]
  ) {
    self.name = name
    self.nextLaneSequence = nextLaneSequence
    self.nextTicketSequence = nextTicketSequence
    self.nextChecklistSequence = nextChecklistSequence
    self.nextCommentSequence = nextCommentSequence
    self.lanes = lanes
  }

  init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Taskboard"
    nextLaneSequence = try container.decodeIfPresent(Int.self, forKey: .nextLaneSequence) ?? 1
    nextTicketSequence = try container.decodeIfPresent(Int.self, forKey: .nextTicketSequence) ?? 1
    nextChecklistSequence = try container.decodeIfPresent(Int.self, forKey: .nextChecklistSequence) ?? 1
    nextCommentSequence = try container.decodeIfPresent(Int.self, forKey: .nextCommentSequence) ?? 1
    lanes = try container.decodeIfPresent([TaskboardLane].self, forKey: .lanes) ?? []
  }

  func normalized() -> TaskboardBoard {
    var normalizedBoard = self
    normalizedBoard.lanes = normalizedBoard.lanes
      .sorted {
        if $0.order == $1.order {
          return $0.id < $1.id
        }

        return $0.order < $1.order
      }
      .enumerated()
      .map { index, lane in
        var normalizedLane = lane
        normalizedLane.order = index + 1
        if let wipLimit = normalizedLane.wipLimit, wipLimit <= 0 {
          normalizedLane.wipLimit = nil
        }
        normalizedLane.tickets = normalizedLane.tickets.map { ticket in
          var normalizedTicket = ticket
          normalizedTicket.labels = Array(
            Set(
              normalizedTicket.labels
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            )
          )
          .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

          if TaskboardDateCoder.parseDateOnly(normalizedTicket.dueDateISO8601) == nil {
            normalizedTicket.dueDateISO8601 = nil
          }

          normalizedTicket.checklist = normalizedTicket.checklist.map { item in
            var normalizedItem = item
            normalizedItem.title = normalizedItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedItem
          }
          .filter { !$0.title.isEmpty }

          normalizedTicket.assignees = normalizedTicket.assignees
            .map { assignee in
              var normalizedAssignee = assignee
              normalizedAssignee.displayName = normalizedAssignee.displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)
              normalizedAssignee.id = TaskboardMemberCoder.memberID(from: normalizedAssignee.displayName)
              return normalizedAssignee
            }
            .filter { !$0.displayName.isEmpty }

          if normalizedTicket.assignees.isEmpty {
            let fallbackOwner = normalizedTicket.owner.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallbackOwner.isEmpty && fallbackOwner.caseInsensitiveCompare("Unassigned") != .orderedSame {
              normalizedTicket.assignees = [
                TaskboardAssignee(
                  id: TaskboardMemberCoder.memberID(from: fallbackOwner),
                  displayName: fallbackOwner
                )
              ]
            }
          }

          normalizedTicket.owner = normalizedTicket.assignees.first?.displayName ?? "Unassigned"
          normalizedTicket.descriptionMarkdown = normalizedTicket.descriptionMarkdown
            .trimmingCharacters(in: .whitespacesAndNewlines)

          normalizedTicket.comments = normalizedTicket.comments
            .enumerated()
            .map { commentIndex, comment in
              var normalizedComment = comment
              normalizedComment.author = normalizedComment.author
                .trimmingCharacters(in: .whitespacesAndNewlines)
              normalizedComment.bodyMarkdown = normalizedComment.bodyMarkdown
                .trimmingCharacters(in: .whitespacesAndNewlines)

              if normalizedComment.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalizedComment.id = "comment-\(commentIndex + 1)"
              }

              if normalizedComment.author.isEmpty {
                normalizedComment.author = "Unassigned"
              }

              return normalizedComment
            }
            .filter { !$0.bodyMarkdown.isEmpty }

          return normalizedTicket
        }

        return normalizedLane
      }

    let nextLaneSequenceCandidate =
      normalizedBoard.lanes.compactMap { lane -> Int? in
        guard lane.id.hasPrefix("lane-") else {
          return nil
        }

        return Int(lane.id.replacingOccurrences(of: "lane-", with: ""))
      }
      .max() ?? 0

    let nextTicketSequenceCandidate =
      normalizedBoard.lanes
      .flatMap(\.tickets)
      .compactMap { ticket -> Int? in
        guard ticket.id.hasPrefix("ticket-") else {
          return nil
        }

        return Int(ticket.id.replacingOccurrences(of: "ticket-", with: ""))
      }
      .max() ?? 0

    let nextChecklistSequenceCandidate =
      normalizedBoard.lanes
      .flatMap(\.tickets)
      .flatMap(\.checklist)
      .compactMap { item -> Int? in
        guard item.id.hasPrefix("check-") else {
          return nil
        }

        return Int(item.id.replacingOccurrences(of: "check-", with: ""))
      }
      .max() ?? 0

    let nextCommentSequenceCandidate =
      normalizedBoard.lanes
      .flatMap(\.tickets)
      .flatMap(\.comments)
      .compactMap { comment -> Int? in
        guard comment.id.hasPrefix("comment-") else {
          return nil
        }

        return Int(comment.id.replacingOccurrences(of: "comment-", with: ""))
      }
      .max() ?? 0

    normalizedBoard.nextLaneSequence = max(normalizedBoard.nextLaneSequence, nextLaneSequenceCandidate + 1)
    normalizedBoard.nextTicketSequence = max(normalizedBoard.nextTicketSequence, nextTicketSequenceCandidate + 1)
    normalizedBoard.nextChecklistSequence = max(
      normalizedBoard.nextChecklistSequence,
      nextChecklistSequenceCandidate + 1
    )
    normalizedBoard.nextCommentSequence = max(normalizedBoard.nextCommentSequence, nextCommentSequenceCandidate + 1)
    return normalizedBoard
  }
}

struct TaskboardLane: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var templateID: String?
  var order: Int
  var wipLimit: Int?
  var isCollapsed: Bool
  var tickets: [TaskboardTicket]

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case templateID
    case order
    case wipLimit
    case isCollapsed
    case tickets
  }

  init(
    id: String,
    title: String,
    templateID: String?,
    order: Int,
    wipLimit: Int?,
    isCollapsed: Bool,
    tickets: [TaskboardTicket]
  ) {
    self.id = id
    self.title = title
    self.templateID = templateID
    self.order = order
    self.wipLimit = wipLimit
    self.isCollapsed = isCollapsed
    self.tickets = tickets
  }

  init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Lane"
    templateID = try container.decodeIfPresent(String.self, forKey: .templateID)
    order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
    wipLimit = try container.decodeIfPresent(Int.self, forKey: .wipLimit)
    isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
    tickets = try container.decodeIfPresent([TaskboardTicket].self, forKey: .tickets) ?? []
  }
}

struct TaskboardTicket: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var owner: String
  var assignees: [TaskboardAssignee]
  var priority: TaskboardTicketPriority
  var labels: [String]
  var dueDateISO8601: String?
  var checklist: [TaskboardChecklistItem]
  var descriptionMarkdown: String
  var comments: [TaskboardComment]

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case owner
    case assignees
    case priority
    case labels
    case dueDateISO8601
    case checklist
    case descriptionMarkdown
    case comments
  }

  init(
    id: String,
    title: String,
    owner: String,
    assignees: [TaskboardAssignee],
    priority: TaskboardTicketPriority,
    labels: [String],
    dueDateISO8601: String?,
    checklist: [TaskboardChecklistItem],
    descriptionMarkdown: String,
    comments: [TaskboardComment]
  ) {
    self.id = id
    self.title = title
    self.owner = owner
    self.assignees = assignees
    self.priority = priority
    self.labels = labels
    self.dueDateISO8601 = dueDateISO8601
    self.checklist = checklist
    self.descriptionMarkdown = descriptionMarkdown
    self.comments = comments
  }

  init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
    owner = try container.decodeIfPresent(String.self, forKey: .owner) ?? "Unassigned"
    assignees = try container.decodeIfPresent([TaskboardAssignee].self, forKey: .assignees) ?? []
    priority = try container.decodeIfPresent(TaskboardTicketPriority.self, forKey: .priority) ?? .medium
    labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
    dueDateISO8601 = try container.decodeIfPresent(String.self, forKey: .dueDateISO8601)
    checklist = try container.decodeIfPresent([TaskboardChecklistItem].self, forKey: .checklist) ?? []
    descriptionMarkdown = try container.decodeIfPresent(String.self, forKey: .descriptionMarkdown) ?? ""
    comments = try container.decodeIfPresent([TaskboardComment].self, forKey: .comments) ?? []
  }
}

struct TaskboardChecklistItem: Codable, Equatable, Identifiable {
  var id: String
  var title: String
  var isComplete: Bool
}

struct TaskboardAssignee: Codable, Equatable, Identifiable {
  var id: String
  var displayName: String
}

struct TaskboardComment: Codable, Equatable, Identifiable {
  var id: String
  var author: String
  var bodyMarkdown: String
}

enum TaskboardTicketPriority: String, Codable, CaseIterable, Identifiable {
  case high
  case medium
  case low

  var id: String {
    rawValue
  }

  var label: String {
    rawValue.capitalized
  }
}

struct TaskboardLaneTemplate: Identifiable {
  let id: String
  let title: String
  let detail: String

  static let defaults: [TaskboardLaneTemplate] = [
    TaskboardLaneTemplate(id: "inbox", title: "Inbox", detail: "Capture new ideas and requests"),
    TaskboardLaneTemplate(id: "ready", title: "Ready", detail: "Refined and ready to start"),
    TaskboardLaneTemplate(id: "in-progress", title: "In Progress", detail: "Active implementation work"),
    TaskboardLaneTemplate(id: "blocked", title: "Blocked", detail: "Waiting on dependency or decision"),
    TaskboardLaneTemplate(id: "review", title: "Review", detail: "Pending quality and approval pass"),
    TaskboardLaneTemplate(id: "done", title: "Done", detail: "Completed and accepted"),
  ]
}

enum DueDateFilter: String, CaseIterable, Identifiable {
  case all
  case withDueDate
  case overdue
  case noDueDate

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .all:
      return "All Due States"
    case .withDueDate:
      return "Has Due Date"
    case .overdue:
      return "Overdue"
    case .noDueDate:
      return "No Due Date"
    }
  }
}

enum TaskboardMemberCoder {
  static func memberID(
    from name: String
  ) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return "member-unassigned"
    }

    let collapsed =
      trimmed
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    if collapsed.isEmpty {
      return "member-unassigned"
    }

    return "member-\(collapsed)"
  }
}

enum TaskboardDateCoder {
  static func parseDateOnly(
    _ value: String?
  ) -> DateComponents? {
    guard let value else {
      return nil
    }

    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2]),
      (1...12).contains(month),
      (1...31).contains(day)
    else {
      return nil
    }

    var components = DateComponents()
    components.calendar = storageCalendar
    components.year = year
    components.month = month
    components.day = day
    return components
  }

  static func date(
    fromDateOnly value: String?
  ) -> Date? {
    guard let components = parseDateOnly(value) else {
      return nil
    }

    var localComponents = components
    localComponents.calendar = displayCalendar
    localComponents.timeZone = displayCalendar.timeZone
    localComponents.hour = 12
    localComponents.minute = 0
    localComponents.second = 0
    return displayCalendar.date(from: localComponents)
  }

  static func encodeDateOnly(
    from date: Date?
  ) -> String? {
    guard let date else {
      return nil
    }

    let components = displayCalendar.dateComponents([.year, .month, .day], from: date)
    guard let year = components.year,
      let month = components.month,
      let day = components.day
    else {
      return nil
    }

    return String(format: "%04d-%02d-%02d", year, month, day)
  }

  static func isOverdue(
    _ value: String?,
    relativeTo currentDate: Date = Date()
  ) -> Bool {
    guard let dueComponents = parseDateOnly(value),
      let dueYear = dueComponents.year,
      let dueMonth = dueComponents.month,
      let dueDay = dueComponents.day
    else {
      return false
    }

    let todayComponents = displayCalendar.dateComponents([.year, .month, .day], from: currentDate)
    guard let todayYear = todayComponents.year,
      let todayMonth = todayComponents.month,
      let todayDay = todayComponents.day
    else {
      return false
    }

    return (dueYear, dueMonth, dueDay) < (todayYear, todayMonth, todayDay)
  }

  static func displayText(
    fromDateOnly value: String?
  ) -> String? {
    guard let date = date(fromDateOnly: value) else {
      return nil
    }

    let formatter = DateFormatter()
    formatter.calendar = displayCalendar
    formatter.locale = displayLocale
    formatter.timeZone = displayCalendar.timeZone
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  private static let displayLocale = Locale.autoupdatingCurrent

  private static let displayCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale.autoupdatingCurrent
    calendar.timeZone = .autoupdatingCurrent
    return calendar
  }()

  private static let storageCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
    return calendar
  }()
}
