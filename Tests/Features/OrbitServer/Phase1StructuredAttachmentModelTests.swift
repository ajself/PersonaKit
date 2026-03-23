import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1StructuredAttachmentModelTests {
  @Test
  func orderedStructuredObjectsFollowAttachmentOrderAcrossMixedObjectTypes() {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_800)
    let postID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let noteID = UUID(uuidString: "aaaaaaaa-1111-2222-3333-444444444444")!
    let decisionID = UUID(uuidString: "bbbbbbbb-1111-2222-3333-444444444444")!
    let referenceID = UUID(uuidString: "cccccccc-1111-2222-3333-444444444444")!
    let artifactID = UUID(uuidString: "dddddddd-1111-2222-3333-444444444444")!

    let snapshot = OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: createdAt
      ),
      channel: OrbitChannelRecord(
        id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
        workspaceID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary room",
        status: .active,
        createdAt: createdAt
      ),
      post: OrbitPostRecord(
        id: postID,
        workspaceID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
        channelID: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Structured attachment model",
        status: .active,
        createdAt: createdAt
      ),
      thread: OrbitThreadRecord(
        id: UUID(uuidString: "abcdefab-cdef-cdef-cdef-abcdefabcdef")!,
        postID: postID,
        status: .open,
        lastActivityAt: createdAt,
        createdAt: createdAt
      ),
      messages: [],
      notes: [
        OrbitNoteRecord(
          id: noteID,
          postID: postID,
          noteType: .meetingSummary,
          body: "One durable summary.",
          createdByParticipantType: .system,
          createdByParticipantID: "orbit-system",
          createdAt: createdAt
        )
      ],
      decisions: [
        OrbitDecisionRecord(
          id: decisionID,
          postID: postID,
          title: "Adopt the attachment slice",
          body: "Keep one attachment lane for structured objects.",
          decisionState: .adopted,
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: createdAt.addingTimeInterval(1)
        )
      ],
      references: [
        OrbitReferenceRecord(
          id: referenceID,
          postID: postID,
          referenceType: .doc,
          target: "Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md",
          title: "Runtime model RFC",
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: createdAt.addingTimeInterval(2)
        )
      ],
      artifacts: [
        OrbitArtifactRecord(
          id: artifactID,
          postID: postID,
          artifactType: .report,
          storageRef: "reports/m6-p2-slice.md",
          title: "M6 P2 Slice",
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          createdAt: createdAt.addingTimeInterval(3)
        )
      ],
      structuredAttachments: [
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .artifact,
          structuredObjectID: artifactID,
          attachmentOrdinal: 0,
          attachedAt: createdAt.addingTimeInterval(10)
        ),
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .note,
          structuredObjectID: noteID,
          attachmentOrdinal: 1,
          attachedAt: createdAt.addingTimeInterval(11)
        ),
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .decision,
          structuredObjectID: decisionID,
          attachmentOrdinal: 2,
          attachedAt: createdAt.addingTimeInterval(12)
        ),
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .reference,
          structuredObjectID: referenceID,
          attachmentOrdinal: 3,
          attachedAt: createdAt.addingTimeInterval(13)
        ),
      ]
    )

    #expect(snapshot.orderedStructuredObjects.map(\.id) == [artifactID, noteID, decisionID, referenceID])
  }
}
