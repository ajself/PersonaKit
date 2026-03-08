import Foundation

enum TaskboardInteractionEventKind: String, CaseIterable, Codable {
  case createLane = "create_lane"
  case editLane = "edit_lane"
  case reorderLane = "reorder_lane"
  case deleteLane = "delete_lane"
  case createTicket = "create_ticket"
  case editTicket = "edit_ticket"
  case moveTicket = "move_ticket"
  case reorderTicket = "reorder_ticket"
  case deleteTicket = "delete_ticket"
  case collapseLane = "collapse_lane"
  case expandLane = "expand_lane"
}

struct TaskboardInteractionEvent: Codable, Equatable {
  let sequence: Int
  let kind: TaskboardInteractionEventKind
  let details: [String: String]
}

enum TaskboardNightShiftReporter {
  static func nextSequence(
    for events: [TaskboardInteractionEvent]
  ) -> Int {
    (events.map(\.sequence).max() ?? 0) + 1
  }

  static func loadEvents(
    from fileURL: URL
  ) throws -> [TaskboardInteractionEvent] {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      return []
    }

    let data = try Data(contentsOf: fileURL)
    guard let contents = String(data: data, encoding: .utf8) else {
      return []
    }

    let decoder = JSONDecoder()
    return
      try contents
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .map { line in
        guard let lineData = line.data(using: .utf8) else {
          throw CocoaError(.coderInvalidValue)
        }

        return try decoder.decode(TaskboardInteractionEvent.self, from: lineData)
      }
  }

  static func appendEvent(
    _ event: TaskboardInteractionEvent,
    to fileURL: URL
  ) throws {
    let fileManager = FileManager.default
    let directoryURL = fileURL.deletingLastPathComponent()

    try fileManager.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let eventData = try encoder.encode(event)

    guard var line = String(data: eventData, encoding: .utf8) else {
      throw CocoaError(.coderInvalidValue)
    }

    line.append("\n")
    let lineData = Data(line.utf8)

    if fileManager.fileExists(atPath: fileURL.path()) {
      let handle = try FileHandle(forWritingTo: fileURL)
      defer {
        try? handle.close()
      }

      try handle.seekToEnd()
      try handle.write(contentsOf: lineData)
    } else {
      try lineData.write(to: fileURL, options: .atomic)
    }
  }

  static func makeReport(
    boardName: String,
    events: [TaskboardInteractionEvent]
  ) -> String {
    let countsByKind = Dictionary(grouping: events, by: \.kind)
      .mapValues(\.count)

    let kindLines = TaskboardInteractionEventKind.allCases
      .map { kind in
        "| `\(kind.rawValue)` | \(countsByKind[kind, default: 0]) |"
      }
      .joined(separator: "\n")

    let firstSequence = events.first?.sequence ?? 0
    let lastSequence = events.last?.sequence ?? 0

    return """
      # Taskboard Night Shift Report

      Generated: deterministic from local telemetry events (no wall-clock timestamps).
      Board: `\(boardName)`
      Event Count: `\(events.count)`
      Sequence Range: `\(firstSequence)` -> `\(lastSequence)`

      ## Event Counts

      | Event | Count |
      | --- | ---: |
      \(kindLines)

      ## Notes

      1. This report is generated from `.personakit/Taskboard/night-shift/interaction-events.jsonl`.
      2. This file is deterministic for the same event sequence input.
      """
  }
}
