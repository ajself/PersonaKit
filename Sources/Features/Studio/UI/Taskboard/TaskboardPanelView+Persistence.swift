import Foundation
import SwiftUI

extension TaskboardPanelView {
  func taskboardNightShiftDirectoryURL(
    for workspaceURL: URL
  ) -> URL {
    workspaceURL
      .standardizedFileURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
      .appendingPathComponent("night-shift", isDirectory: true)
  }

  func taskboardFileURL(
    for workspaceURL: URL
  ) -> URL {
    workspaceURL
      .standardizedFileURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
      .appendingPathComponent("taskboard.json", isDirectory: false)
  }

  func taskboardInteractionEventsFileURL(
    for workspaceURL: URL
  ) -> URL {
    taskboardNightShiftDirectoryURL(for: workspaceURL)
      .appendingPathComponent("interaction-events.jsonl", isDirectory: false)
  }

  func taskboardNightShiftReportFileURL(
    for workspaceURL: URL
  ) -> URL {
    taskboardNightShiftDirectoryURL(for: workspaceURL)
      .appendingPathComponent("interaction-report.md", isDirectory: false)
  }

  func loadInteractionEventSequence() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      interactionEventSequence = 1
      return
    }

    let eventsFileURL = taskboardInteractionEventsFileURL(for: workspaceURL)

    do {
      let events = try TaskboardNightShiftReporter.loadEvents(from: eventsFileURL)
      interactionEventSequence = TaskboardNightShiftReporter.nextSequence(for: events)
    } catch {
      interactionEventSequence = 1
    }
  }

  func recordInteractionEvent(
    _ kind: TaskboardInteractionEventKind,
    details: [String: String] = [:]
  ) {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    let eventsFileURL = taskboardInteractionEventsFileURL(for: workspaceURL)
    let event = TaskboardInteractionEvent(
      sequence: interactionEventSequence,
      kind: kind,
      details: details
    )

    do {
      try TaskboardNightShiftReporter.appendEvent(event, to: eventsFileURL)
      interactionEventSequence += 1
    } catch {
      persistenceMessage = "Failed to log Taskboard interaction: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  func generateNightShiftReport() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      persistenceMessage = "Open a workspace before generating a night-shift report."
      persistenceIsError = true
      return
    }

    let eventsFileURL = taskboardInteractionEventsFileURL(for: workspaceURL)
    let reportFileURL = taskboardNightShiftReportFileURL(for: workspaceURL)

    do {
      let events = try TaskboardNightShiftReporter.loadEvents(from: eventsFileURL)
      let report = TaskboardNightShiftReporter.makeReport(
        boardName: board.name,
        events: events
      )

      try report.write(to: reportFileURL, atomically: true, encoding: .utf8)
      persistenceMessage = "Night-shift report updated (\(events.count) events)."
      persistenceIsError = false
    } catch {
      persistenceMessage = "Failed to generate night-shift report: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  func loadBoard() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      board = TaskboardBoard.defaultBoard
      selectedLaneID =
        board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = nil
      persistenceIsError = false
      interactionEventSequence = 1
      return
    }

    let fileURL = taskboardFileURL(for: workspaceURL)
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      board = TaskboardBoard.defaultBoard
      selectedLaneID =
        board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = nil
      persistenceIsError = false
      loadInteractionEventSequence()
      return
    }

    do {
      let data = try Data(contentsOf: fileURL)
      let decodedBoard = try JSONDecoder().decode(TaskboardBoard.self, from: data)
      board = decodedBoard.normalized()
      selectedLaneID =
        board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = nil
      persistenceIsError = false
      loadInteractionEventSequence()
    } catch {
      board = TaskboardBoard.defaultBoard
      selectedLaneID =
        board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = "Failed to load Taskboard data: \(error.localizedDescription)"
      persistenceIsError = true
      loadInteractionEventSequence()
    }
  }

  func persistBoard() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    let fileURL = taskboardFileURL(for: workspaceURL)
    let directoryURL = fileURL.deletingLastPathComponent()
    let fileManager = FileManager.default

    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )

      let normalizedBoard = board.normalized()
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(normalizedBoard)
      try data.write(to: fileURL, options: .atomic)

      persistenceMessage = nil
      persistenceIsError = false
    } catch {
      persistenceMessage = "Failed to save Taskboard data: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }
}
