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

    func testOrbitEmptyWorkspace() throws {
      var workspace = OrbitWorkspace.defaultWorkspace
      workspace.threads = workspace.threads.map { thread in
        OrbitConversationThread(
          id: thread.id,
          title: thread.title,
          interactionMode: thread.interactionMode,
          createdSequence: thread.createdSequence,
          updatedSequence: thread.updatedSequence,
          messages: []
        )
      }
      workspace.activationRecords = []
      workspace.activationContractSnapshots = []
      workspace.activationFailureRecords = []
      workspace.nextMessageSequence = 1
      workspace.nextActivationSequence = 1
      workspace.nextActivationFailureSequence = 1

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
        named: "orbit-empty-workspace"
      )
    }

    func testOrbitDirectAddressConversation() throws {
      var workspace = OrbitWorkspace.defaultWorkspace
      workspace.appendConversationTurn(
        body: "Samwise, anchor the next Orbit checkpoint step.",
        addressedParticipantID: OrbitParticipantID.samwise.rawValue
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
        named: "orbit-direct-address-conversation"
      )
    }

    func testOrbitDirectAddressTraceExpanded() throws {
      var workspace = OrbitWorkspace.defaultWorkspace
      let createdMessages = workspace.appendConversationTurn(
        body: "Samwise, explain why this response happened.",
        addressedParticipantID: OrbitParticipantID.samwise.rawValue
      )
      let responseMessageID = try XCTUnwrap(
        createdMessages.last(where: { $0.kind == .participantResponse })?.id
      )

      let workspaceURL = try makeWorkspace(with: workspace)

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeHostingView(
        workspaceStore: store,
        width: 1500,
        height: 920,
        initialExpandedTraceMessageIDs: [responseMessageID]
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "orbit-direct-address-trace-expanded"
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

      try fileManager.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
      try OrbitWorkspacePersistence().persist(orbitWorkspace, to: workspaceURL)

      return workspaceURL.standardizedFileURL
    }

    private func makeHostingView(
      workspaceStore: WorkspaceStore,
      width: CGFloat,
      height: CGFloat,
      initialExpandedTraceMessageIDs: Set<String> = []
    ) -> NSView {
      let rootView = OrbitPanelView(
        workspaceStore: workspaceStore,
        initialExpandedTraceMessageIDs: initialExpandedTraceMessageIDs
      )
        .frame(width: width, height: height)
      let hostingView = NSHostingView(rootView: rootView)
      hostingView.frame = CGRect(x: 0, y: 0, width: width, height: height)
      hostingView.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.2))
      return hostingView
    }
  }
#endif
