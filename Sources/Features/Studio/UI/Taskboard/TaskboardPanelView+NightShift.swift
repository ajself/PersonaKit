import Foundation

struct TaskboardNightShiftEvent: Codable, Equatable {
  enum Kind: String, Codable, CaseIterable {
    case collapseLane
    case createTicket
    case editTicket
    case expandLane
    case moveTicket
    case reorderTicket
  }

  var destinationIndex: Int?
  var destinationLaneID: String?
  var destinationLaneTitle: String?
  var kind: Kind
  var laneID: String?
  var laneTitle: String?
  var sequence: Int
  var sourceLaneID: String?
  var sourceLaneTitle: String?
  var ticketID: String?
  var ticketTitle: String?
}

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

  func taskboardNightShiftEventsFileURL(
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

  func recordNightShiftEvent(
    kind: TaskboardNightShiftEvent.Kind,
    lane: TaskboardLane? = nil,
    ticket: TaskboardTicket? = nil,
    sourceLane: TaskboardLane? = nil,
    destinationLane: TaskboardLane? = nil,
    destinationIndex: Int? = nil
  ) {
    let event = TaskboardNightShiftEvent(
      destinationIndex: destinationIndex,
      destinationLaneID: destinationLane?.id,
      destinationLaneTitle: destinationLane?.title,
      kind: kind,
      laneID: lane?.id,
      laneTitle: lane?.title,
      sequence: nightShiftEvents.count + 1,
      sourceLaneID: sourceLane?.id,
      sourceLaneTitle: sourceLane?.title,
      ticketID: ticket?.id,
      ticketTitle: ticket?.title
    )

    nightShiftEvents.append(event)
    persistNightShiftEvents()
  }

  func persistNightShiftEvents() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    let directoryURL = taskboardNightShiftDirectoryURL(for: workspaceURL)
    let eventsFileURL = taskboardNightShiftEventsFileURL(for: workspaceURL)
    let fileManager = FileManager.default

    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let encodedLines = try nightShiftEvents.map { event in
        let data = try encoder.encode(event)

        guard let line = String(data: data, encoding: .utf8) else {
          throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        return line
      }

      let contents =
        encodedLines.isEmpty
        ? ""
        : encodedLines.joined(separator: "\n") + "\n"

      try contents.write(to: eventsFileURL, atomically: true, encoding: .utf8)
    } catch {
      persistenceMessage = "Failed to save Taskboard interaction log: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  func generateNightShiftReport() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      persistenceMessage = "Select a workspace before generating the Taskboard night-shift report."
      persistenceIsError = true
      return
    }

    persistNightShiftEvents()

    do {
      let directoryURL = taskboardNightShiftDirectoryURL(for: workspaceURL)
      let reportFileURL = taskboardNightShiftReportFileURL(for: workspaceURL)
      let fileManager = FileManager.default

      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )

      let report = nightShiftReportMarkdown(for: workspaceURL)
      try report.write(to: reportFileURL, atomically: true, encoding: .utf8)
      persistenceMessage = "Generated Taskboard night-shift report."
      persistenceIsError = false
    } catch {
      persistenceMessage = "Failed to generate Taskboard night-shift report: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  func nightShiftReportMarkdown(
    for workspaceURL: URL
  ) -> String {
    let eventCounts = Dictionary(grouping: nightShiftEvents, by: \.kind)
      .mapValues(\.count)

    let summaryLines = TaskboardNightShiftEvent.Kind.allCases
      .filter { kind in
        eventCounts[kind, default: 0] > 0
      }
      .map { kind in
        "- `\(kind.rawValue)`: \(eventCounts[kind, default: 0])"
      }

    let eventLines = nightShiftEvents.map { event in
      var fragments = ["\(event.sequence). `\(event.kind.rawValue)`"]

      if let ticketTitle = event.ticketTitle {
        fragments.append("ticket `\(ticketTitle)`")
      }

      if let laneTitle = event.laneTitle {
        fragments.append("lane `\(laneTitle)`")
      }

      if let sourceLaneTitle = event.sourceLaneTitle,
        let destinationLaneTitle = event.destinationLaneTitle
      {
        fragments.append("from `\(sourceLaneTitle)` to `\(destinationLaneTitle)`")
      }

      if let destinationIndex = event.destinationIndex {
        fragments.append("position \(destinationIndex + 1)")
      }

      return "- " + fragments.joined(separator: " | ")
    }

    let bundleVersion =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "dev"
    let buildNumber =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ?? "dev"

    return """
      # Taskboard Night Shift Report

      ## Scope under review
      - Surface: Taskboard
      - Workspace: \(workspaceURL.lastPathComponent)

      ## Build/version context
      - App: PersonaKit
      - Version: \(bundleVersion) (\(buildNumber))
      - Event count: \(nightShiftEvents.count)

      ## Flows tested
      \(summaryLines.isEmpty ? "- No Taskboard interactions were recorded." : summaryLines.joined(separator: "\n"))

      ## Interaction log
      \(eventLines.isEmpty ? "- No Taskboard interactions were recorded." : eventLines.joined(separator: "\n"))

      ## Next checkpoint
      - Run `studio-interaction-quality` using this Taskboard artifact set.
      """
  }
}
