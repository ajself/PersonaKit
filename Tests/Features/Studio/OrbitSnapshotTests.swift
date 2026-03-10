#if os(macOS)
  import AppKit
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import XCTest

  @testable import StudioFeatures

  @MainActor
  final class OrbitSnapshotTests: XCTestCase {
    override func invokeTest() {
      let recordMode: SnapshotTestingConfiguration.Record =
        ProcessInfo.processInfo
          .environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing

      withSnapshotTesting(record: recordMode) {
        super.invokeTest()
      }
    }

    func testOrbitDefaultWorkspace() throws {
      let workspaceURL = try makeWorkspace(with: .defaultWorkspace)

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
        named: "orbit-default-workspace"
      )
    }

    func testOrbitMeetingConversation() throws {
      var workspace = OrbitWorkspace.defaultWorkspace
      workspace.appendConversationTurn(
        body: "Founding group, align on the next Orbit checkpoint.",
        addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue
      )

      let workspaceURL = try makeWorkspace(with: workspace)

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
        named: "orbit-meeting-conversation"
      )
    }

    private func makeWorkspace(
      with orbitWorkspace: OrbitWorkspace
    ) throws -> URL {
      let fileManager = FileManager.default
      let workspaceURL = fileManager.temporaryDirectory
        .appendingPathComponent("orbit-snapshot-\(UUID().uuidString)", isDirectory: true)
      let orbitDirectory =
        workspaceURL
        .appendingPathComponent(".personakit", isDirectory: true)
        .appendingPathComponent("Orbit", isDirectory: true)
      let orbitFileURL =
        orbitDirectory.appendingPathComponent("orbit-workspace.json", isDirectory: false)

      try fileManager.createDirectory(
        at: orbitDirectory,
        withIntermediateDirectories: true
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(orbitWorkspace)
      try data.write(to: orbitFileURL, options: .atomic)

      return workspaceURL.standardizedFileURL
    }

    private func makeHostingView(
      workspaceStore: WorkspaceStore,
      width: CGFloat,
      height: CGFloat
    ) -> NSView {
      let rootView = OrbitPanelView(workspaceStore: workspaceStore)
        .frame(width: width, height: height)
      let hostingView = NSHostingView(rootView: rootView)
      hostingView.frame = CGRect(x: 0, y: 0, width: width, height: height)
      hostingView.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.2))
      return hostingView
    }
  }
#endif
