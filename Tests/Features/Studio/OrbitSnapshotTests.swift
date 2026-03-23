#if os(macOS)
  import AppKit
  import Foundation
  @testable import OrbitServerRuntime
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

    func testOrbitStructuredNotesAndDecisionsMessagePost() throws {
      let workspaceURL = try makeWorkspace(with: structuredMessageWorkspace())

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
        named: "orbit-structured-message-post"
      )
    }

    func testOrbitStructuredNotesAndDecisionsMeetingPost() throws {
      let workspaceURL = try makeWorkspace(with: structuredMeetingWorkspace())

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeHostingView(
        workspaceStore: store,
        width: 1500,
        height: 1040
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "orbit-structured-meeting-post"
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

  private func structuredMessageWorkspace() -> OrbitWorkspace {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-message-structured"
    let referenceID = UUID(uuidString: "a1a1a1a1-1111-2222-3333-444444444444")!
    let decisionID = UUID(uuidString: "b2b2b2b2-1111-2222-3333-444444444444")!

    workspace.orderedStructuredObjectRecords = [
      OrbitStructuredPostObjectRecord(
        id: "note:c3c3c3c3-1111-2222-3333-444444444444",
        originPostID: "post-message-structured",
        structuredObjectType: .note,
        structuredObjectID: "c3c3c3c3-1111-2222-3333-444444444444",
        attachmentOrdinal: 0,
        attachedAt: Date(timeIntervalSince1970: 1_742_342_910),
        object: .note(
          OrbitNoteRecord(
            id: UUID(uuidString: "c3c3c3c3-1111-2222-3333-444444444444")!,
            postID: UUID(uuidString: "11111111-aaaa-bbbb-cccc-111111111111")!,
            noteType: .brief,
            body: "Keep the first structured surface read-only and tied to one originating post.",
            createdByParticipantType: .user,
            createdByParticipantID: OrbitParticipantID.aj.rawValue,
            createdAt: Date(timeIntervalSince1970: 1_742_342_910)
          )
        )
      ),
      OrbitStructuredPostObjectRecord(
        id: "decision:\(decisionID.uuidString)",
        originPostID: "post-message-structured",
        structuredObjectType: .decision,
        structuredObjectID: decisionID.uuidString,
        attachmentOrdinal: 1,
        attachedAt: Date(timeIntervalSince1970: 1_742_342_911),
        object: .decision(
          OrbitDecisionRecord(
            id: decisionID,
            postID: UUID(uuidString: "11111111-aaaa-bbbb-cccc-111111111111")!,
            title: "Ship a read-only structured card first",
            body: "Use the ordered attachment lane for note and decision inspection before adding editing flows.",
            decisionState: .adopted,
            rationale: "The runtime already preserves the canonical order and full decision payload.",
            tradeoffs: "Adds a second read-only card to the room surface.",
            dissent: "none recorded",
            linkedReferenceIDs: [referenceID],
            createdByParticipantType: .workspacePersona,
            createdByParticipantID: "workspace-persona-orbit-samwise",
            createdAt: Date(timeIntervalSince1970: 1_742_342_911)
          )
        )
      ),
      OrbitStructuredPostObjectRecord(
        id: "reference:\(referenceID.uuidString)",
        originPostID: "post-message-structured",
        structuredObjectType: .reference,
        structuredObjectID: referenceID.uuidString,
        attachmentOrdinal: 2,
        attachedAt: Date(timeIntervalSince1970: 1_742_342_912),
        object: .reference(
          OrbitReferenceRecord(
            id: referenceID,
            postID: UUID(uuidString: "11111111-aaaa-bbbb-cccc-111111111111")!,
            referenceType: .doc,
            target: "Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md",
            title: "M6 milestone packet",
            createdByParticipantType: .user,
            createdByParticipantID: OrbitParticipantID.aj.rawValue,
            createdAt: Date(timeIntervalSince1970: 1_742_342_912)
          )
        )
      ),
    ]

    return workspace
  }

  private func structuredMeetingWorkspace() -> OrbitWorkspace {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-meeting-structured"
    let summaryDate = Date(timeIntervalSince1970: 1_742_342_930)
    let referenceID = UUID(uuidString: "d4d4d4d4-1111-2222-3333-444444444444")!
    let decisionID = UUID(uuidString: "e5e5e5e5-1111-2222-3333-444444444444")!

    workspace.meetingSummaryRecords = [
      OrbitMeetingSummaryRecord(
        id: "meeting-summary-structured",
        postID: "post-meeting-structured",
        postTitle: "Structured meeting",
        body: "The meeting confirmed we should ship the structured read-only surface first.",
        createdByParticipantType: .system,
        createdByParticipantID: "orbit-system",
        createdAt: summaryDate
      )
    ]
    workspace.meetingStatusRecords = [
      OrbitMeetingStatusRecord(
        id: "meeting-status-structured",
        postID: "post-meeting-structured",
        meetingType: .team,
        status: .completed,
        startedByParticipantType: .user,
        startedByParticipantID: OrbitParticipantID.aj.rawValue,
        startedAt: summaryDate,
        completedAt: summaryDate.addingTimeInterval(120)
      )
    ]
    workspace.meetingOutcomeRecords = [
      OrbitMeetingOutcomeRecord(
        id: "meeting-outcome-structured",
        postID: "post-meeting-structured",
        outcomeState: .decisionRecorded,
        detail: "The packet stays read-only in this slice.",
        recordedByParticipantType: .user,
        recordedByParticipantID: OrbitParticipantID.aj.rawValue,
        recordedAt: summaryDate.addingTimeInterval(120)
      )
    ]
    workspace.meetingDecisionRecords = [
      OrbitMeetingDecisionRecord(
        id: "meeting-decision-structured",
        postID: "post-meeting-structured",
        title: "Ship the read-only structured surface",
        body: "Preserve the existing meeting outputs card and add the new structured card below it.",
        decisionState: .adopted,
        rationaleNoteID: nil,
        createdAt: summaryDate.addingTimeInterval(120)
      )
    ]
    workspace.meetingReferenceRecords = [
      OrbitMeetingReferenceRecord(
        id: "meeting-reference-structured",
        postID: "post-meeting-structured",
        referenceType: .doc,
        target: "Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Packet-01-Freeze-Object-Definitions.md",
        title: "Object freeze",
        createdAt: summaryDate.addingTimeInterval(121)
      )
    ]
    workspace.meetingMemberRecords = [
      OrbitMeetingMemberRecord(
        id: "meeting-member-structured",
        postID: "post-meeting-structured",
        postParticipantID: "meeting-participant-structured",
        participantID: OrbitParticipantID.samwise.rawValue,
        participationRole: .contributor,
        selectedReason: "Trusted partner review for the first structured-object slice.",
        joinedAt: summaryDate,
        completedAt: summaryDate.addingTimeInterval(120)
      )
    ]
    workspace.orderedStructuredObjectRecords = [
      OrbitStructuredPostObjectRecord(
        id: "note:f6f6f6f6-1111-2222-3333-444444444444",
        originPostID: "post-meeting-structured",
        structuredObjectType: .note,
        structuredObjectID: "f6f6f6f6-1111-2222-3333-444444444444",
        attachmentOrdinal: 0,
        attachedAt: summaryDate,
        object: .note(
          OrbitNoteRecord(
            id: UUID(uuidString: "f6f6f6f6-1111-2222-3333-444444444444")!,
            postID: UUID(uuidString: "22222222-aaaa-bbbb-cccc-222222222222")!,
            noteType: .meetingSummary,
            body: "The meeting confirmed we should ship the structured read-only surface first.",
            createdByParticipantType: .system,
            createdByParticipantID: "orbit-system",
            createdAt: summaryDate
          )
        )
      ),
      OrbitStructuredPostObjectRecord(
        id: "decision:\(decisionID.uuidString)",
        originPostID: "post-meeting-structured",
        structuredObjectType: .decision,
        structuredObjectID: decisionID.uuidString,
        attachmentOrdinal: 1,
        attachedAt: summaryDate.addingTimeInterval(120),
        object: .decision(
          OrbitDecisionRecord(
            id: decisionID,
            postID: UUID(uuidString: "22222222-aaaa-bbbb-cccc-222222222222")!,
            title: "Ship the read-only structured surface",
            body: "Keep note and decision inspection in one ordered card without reopening editing UX.",
            decisionState: .adopted,
            rationale: "The ordered attachment lane is already canonical and replay-safe.",
            tradeoffs: "The room gains one more card until later packets unify the surface.",
            dissent: "none recorded",
            linkedReferenceIDs: [referenceID],
            createdByParticipantType: .user,
            createdByParticipantID: OrbitParticipantID.aj.rawValue,
            createdAt: summaryDate.addingTimeInterval(120)
          )
        )
      ),
      OrbitStructuredPostObjectRecord(
        id: "reference:\(referenceID.uuidString)",
        originPostID: "post-meeting-structured",
        structuredObjectType: .reference,
        structuredObjectID: referenceID.uuidString,
        attachmentOrdinal: 2,
        attachedAt: summaryDate.addingTimeInterval(121),
        object: .reference(
          OrbitReferenceRecord(
            id: referenceID,
            postID: UUID(uuidString: "22222222-aaaa-bbbb-cccc-222222222222")!,
            referenceType: .doc,
            target: "Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Packet-01-Freeze-Object-Definitions.md",
            title: "Object freeze",
            createdByParticipantType: .user,
            createdByParticipantID: OrbitParticipantID.aj.rawValue,
            createdAt: summaryDate.addingTimeInterval(121)
          )
        )
      ),
    ]

    return workspace
  }
#endif
