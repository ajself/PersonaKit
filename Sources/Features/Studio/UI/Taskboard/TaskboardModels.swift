import Foundation

struct TaskboardBoard: Codable, Equatable {
  var name: String
  var nextLaneSequence: Int
  var nextTicketSequence: Int
  var nextChecklistSequence: Int
  var lanes: [TaskboardLane]

  private enum CodingKeys: String, CodingKey {
    case name
    case nextLaneSequence
    case nextTicketSequence
    case nextChecklistSequence
    case lanes
  }

  static let defaultBoard = TaskboardBoard(
    name: "Taskboard",
    nextLaneSequence: 7,
    nextTicketSequence: 4,
    nextChecklistSequence: 3,
    lanes: [
      TaskboardLane(id: "lane-1", title: "Inbox", templateID: "inbox", order: 1, tickets: []),
      TaskboardLane(id: "lane-2", title: "Ready", templateID: "ready", order: 2, tickets: []),
      TaskboardLane(
        id: "lane-3",
        title: "In Progress",
        templateID: "in-progress",
        order: 3,
        tickets: [
          TaskboardTicket(
            id: "ticket-1",
            title: "Implement Taskboard lane CRUD",
            owner: "Samwise",
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
            ]
          )
        ]
      ),
      TaskboardLane(id: "lane-4", title: "Blocked", templateID: "blocked", order: 4, tickets: []),
      TaskboardLane(
        id: "lane-5",
        title: "Review",
        templateID: "review",
        order: 5,
        tickets: [
          TaskboardTicket(
            id: "ticket-2",
            title: "Run red-pen interaction review",
            owner: "studio-interaction-quality-lead",
            priority: .medium,
            labels: ["quality"],
            dueDateISO8601: nil,
            checklist: []
          )
        ]
      ),
      TaskboardLane(
        id: "lane-6",
        title: "Done",
        templateID: "done",
        order: 6,
        tickets: [
          TaskboardTicket(
            id: "ticket-3",
            title: "Approve Taskboard feature name",
            owner: "AJ",
            priority: .low,
            labels: ["planning"],
            dueDateISO8601: nil,
            checklist: []
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
    lanes: [TaskboardLane]
  ) {
    self.name = name
    self.nextLaneSequence = nextLaneSequence
    self.nextTicketSequence = nextTicketSequence
    self.nextChecklistSequence = nextChecklistSequence
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
          return normalizedTicket
        }
        return normalizedLane
      }

    let nextLaneSequenceCandidate = normalizedBoard.lanes.compactMap { lane -> Int? in
      guard lane.id.hasPrefix("lane-") else {
        return nil
      }

      return Int(lane.id.replacingOccurrences(of: "lane-", with: ""))
    }
    .max() ?? 0

    let nextTicketSequenceCandidate = normalizedBoard.lanes
      .flatMap(\.tickets)
      .compactMap { ticket -> Int? in
        guard ticket.id.hasPrefix("ticket-") else {
          return nil
        }

        return Int(ticket.id.replacingOccurrences(of: "ticket-", with: ""))
      }
      .max() ?? 0

    let nextChecklistSequenceCandidate = normalizedBoard.lanes
      .flatMap(\.tickets)
      .flatMap(\.checklist)
      .compactMap { item -> Int? in
        guard item.id.hasPrefix("check-") else {
          return nil
        }

        return Int(item.id.replacingOccurrences(of: "check-", with: ""))
      }
      .max() ?? 0

    normalizedBoard.nextLaneSequence = max(normalizedBoard.nextLaneSequence, nextLaneSequenceCandidate + 1)
    normalizedBoard.nextTicketSequence = max(normalizedBoard.nextTicketSequence, nextTicketSequenceCandidate + 1)
    normalizedBoard.nextChecklistSequence = max(normalizedBoard.nextChecklistSequence, nextChecklistSequenceCandidate + 1)
    return normalizedBoard
  }
}

struct TaskboardLane: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var templateID: String?
  var order: Int
  var tickets: [TaskboardTicket]
}

struct TaskboardTicket: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var owner: String
  var priority: TaskboardTicketPriority
  var labels: [String]
  var dueDateISO8601: String?
  var checklist: [TaskboardChecklistItem]

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case owner
    case priority
    case labels
    case dueDateISO8601
    case checklist
  }

  init(
    id: String,
    title: String,
    owner: String,
    priority: TaskboardTicketPriority,
    labels: [String],
    dueDateISO8601: String?,
    checklist: [TaskboardChecklistItem]
  ) {
    self.id = id
    self.title = title
    self.owner = owner
    self.priority = priority
    self.labels = labels
    self.dueDateISO8601 = dueDateISO8601
    self.checklist = checklist
  }

  init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
    owner = try container.decodeIfPresent(String.self, forKey: .owner) ?? "Unassigned"
    priority = try container.decodeIfPresent(TaskboardTicketPriority.self, forKey: .priority) ?? .medium
    labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
    dueDateISO8601 = try container.decodeIfPresent(String.self, forKey: .dueDateISO8601)
    checklist = try container.decodeIfPresent([TaskboardChecklistItem].self, forKey: .checklist) ?? []
  }
}

struct TaskboardChecklistItem: Codable, Equatable, Identifiable {
  var id: String
  var title: String
  var isComplete: Bool
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
