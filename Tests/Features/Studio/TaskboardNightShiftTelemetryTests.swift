import Foundation
import Testing

@testable import StudioFeatures

struct TaskboardNightShiftTelemetryTests {
  @Test
  func nextSequenceReturnsOneWhenNoEvents() {
    let sequence = TaskboardNightShiftReporter.nextSequence(for: [])
    #expect(sequence == 1)
  }

  @Test
  func appendAndLoadEventsPreserveDeterministicOrder() throws {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory
      .appendingPathComponent("taskboard-telemetry-tests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL =
      directoryURL
      .appendingPathComponent("interaction-events.jsonl", isDirectory: false)

    let first = TaskboardInteractionEvent(
      sequence: 1,
      kind: .createTicket,
      details: [
        "laneID": "lane-1",
        "ticketID": "ticket-1",
      ]
    )
    let second = TaskboardInteractionEvent(
      sequence: 2,
      kind: .moveTicket,
      details: [
        "fromLaneID": "lane-1",
        "ticketID": "ticket-1",
        "toLaneID": "lane-2",
      ]
    )

    try TaskboardNightShiftReporter.appendEvent(first, to: fileURL)
    try TaskboardNightShiftReporter.appendEvent(second, to: fileURL)

    let loaded = try TaskboardNightShiftReporter.loadEvents(from: fileURL)
    #expect(loaded == [first, second])
    #expect(TaskboardNightShiftReporter.nextSequence(for: loaded) == 3)
  }

  @Test
  func reportOutputIsDeterministicForSameInput() {
    let events: [TaskboardInteractionEvent] = [
      TaskboardInteractionEvent(
        sequence: 1,
        kind: .createTicket,
        details: ["ticketID": "ticket-1"]
      ),
      TaskboardInteractionEvent(
        sequence: 2,
        kind: .createTicket,
        details: ["ticketID": "ticket-2"]
      ),
      TaskboardInteractionEvent(
        sequence: 3,
        kind: .collapseLane,
        details: ["laneID": "lane-3"]
      ),
    ]

    let first = TaskboardNightShiftReporter.makeReport(
      boardName: "Taskboard",
      events: events
    )
    let second = TaskboardNightShiftReporter.makeReport(
      boardName: "Taskboard",
      events: events
    )

    #expect(first == second)
    #expect(first.contains("Event Count: `3`"))
    #expect(first.contains("`create_ticket` | 2"))
    #expect(first.contains("`collapse_lane` | 1"))
  }
}
