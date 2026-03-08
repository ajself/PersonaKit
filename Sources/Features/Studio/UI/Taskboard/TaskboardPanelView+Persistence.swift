import Foundation
import SwiftUI

extension TaskboardPanelView {
  func taskboardFileURL(
    for workspaceURL: URL
  ) -> URL {
    workspaceURL
      .standardizedFileURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
      .appendingPathComponent("taskboard.json", isDirectory: false)
  }

  func loadBoard() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      board = TaskboardBoard.defaultBoard
      selectedLaneID = board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = nil
      persistenceIsError = false
      return
    }

    let fileURL = taskboardFileURL(for: workspaceURL)
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      board = TaskboardBoard.defaultBoard
      selectedLaneID = board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = nil
      persistenceIsError = false
      return
    }

    do {
      let data = try Data(contentsOf: fileURL)
      let decodedBoard = try JSONDecoder().decode(TaskboardBoard.self, from: data)
      board = decodedBoard.normalized()
      selectedLaneID = board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = nil
      persistenceIsError = false
    } catch {
      board = TaskboardBoard.defaultBoard
      selectedLaneID = board.lanes
        .sorted { $0.order < $1.order }
        .first?
        .id
      persistenceMessage = "Failed to load Taskboard data: \(error.localizedDescription)"
      persistenceIsError = true
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
