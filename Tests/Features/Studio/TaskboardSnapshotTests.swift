#if os(macOS)
import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

@testable import StudioFeatures

@MainActor
final class TaskboardSnapshotTests: XCTestCase {
  override func invokeTest() {
    let recordMode: SnapshotTestingConfiguration.Record = ProcessInfo.processInfo
      .environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing

    withSnapshotTesting(record: recordMode) {
      super.invokeTest()
    }
  }

  func testTaskboardDefaultBoard() throws {
    let store = WorkspaceStore()
    let view = makeHostingView(
      workspaceStore: store,
      width: 1500,
      height: 920
    )

    assertSnapshot(
      of: view,
      as: .image,
      named: "taskboard-default-board"
    )
  }

  func testTaskboardEmptyBoard() throws {
    let workspaceURL = try makeWorkspaceWithBoard(
      TaskboardBoard(
        name: "Taskboard",
        nextLaneSequence: 1,
        nextTicketSequence: 1,
        nextChecklistSequence: 1,
        lanes: []
      )
    )

    let store = WorkspaceStore()
    store.workspaceURL = workspaceURL
    let view = makeHostingView(
      workspaceStore: store,
      width: 1500,
      height: 920
    )

    assertSnapshot(
      of: view,
      as: .image,
      named: "taskboard-empty-board"
    )
  }

  private func makeWorkspaceWithBoard(
    _ board: TaskboardBoard
  ) throws -> URL {
    let fileManager = FileManager.default
    let workspaceURL = fileManager.temporaryDirectory
      .appendingPathComponent("taskboard-snapshot-\(UUID().uuidString)", isDirectory: true)
    let taskboardDirectory = workspaceURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
    let boardFileURL = taskboardDirectory.appendingPathComponent("taskboard.json", isDirectory: false)

    try fileManager.createDirectory(
      at: taskboardDirectory,
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(board)
    try data.write(to: boardFileURL, options: .atomic)
    return workspaceURL.standardizedFileURL
  }

  private func makeHostingView(
    workspaceStore: WorkspaceStore,
    width: CGFloat,
    height: CGFloat
  ) -> NSView {
    let rootView = TaskboardPanelView(workspaceStore: workspaceStore)
      .frame(width: width, height: height)
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    return hostingView
  }
}
#endif
