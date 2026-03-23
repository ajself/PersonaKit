import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

@MainActor
struct OrbitStructuredNotesAndDecisionsPresentationTests {
  @Test
  func surfaceItemsPreserveCanonicalOrderAcrossMixedAttachments() {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-message-0001"
    workspace.orderedStructuredObjectRecords = [
      structuredArtifactRecord(
        id: "11111111-1111-1111-1111-111111111111",
        originPostID: "post-message-0001",
        ordinal: 0
      ),
      structuredNoteRecord(
        id: "22222222-2222-2222-2222-222222222222",
        originPostID: "post-message-0001",
        ordinal: 1,
        noteType: .brief,
        body: "Narrative context",
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      ),
      structuredDecisionRecord(
        id: "33333333-3333-3333-3333-333333333333",
        originPostID: "post-message-0001",
        ordinal: 2,
        title: "Ship the structured card",
        linkedReferenceIDs: [],
        createdByParticipantType: .workspacePersona,
        createdByParticipantID: "workspace-persona-orbit-samwise"
      ),
      structuredReferenceRecord(
        id: "44444444-4444-4444-4444-444444444444",
        originPostID: "post-message-0001",
        ordinal: 3,
        target: "Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md"
      ),
      structuredNoteRecord(
        id: "55555555-5555-5555-5555-555555555555",
        originPostID: "post-message-0001",
        ordinal: 4,
        noteType: .retrospective,
        body: "Capture what we learned.",
        createdByParticipantType: .workspacePersona,
        createdByParticipantID: "workspace-persona-orbit-proddoc"
      ),
    ]

    let surfaceItems = workspace.activeStructuredNotesAndDecisionsSurfaceItems

    #expect(surfaceItems.map(\.id) == [
      "note:22222222-2222-2222-2222-222222222222",
      "decision:33333333-3333-3333-3333-333333333333",
      "note:55555555-5555-5555-5555-555555555555",
    ])
    #expect(surfaceItems.map(\.createdByDisplayName) == ["AJ", "Samwise", "ProdDoc"])
  }

  @Test
  func meetingSummaryNotesBecomeReferenceRowsOnMeetingPosts() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-meeting-0001"
    workspace.meetingStatusRecords = [
      OrbitMeetingStatusRecord(
        id: "meeting-status-0001",
        postID: "post-meeting-0001",
        meetingType: .team,
        status: .completed,
        startedByParticipantType: .user,
        startedByParticipantID: OrbitParticipantID.aj.rawValue,
        startedAt: Date(timeIntervalSince1970: 1_742_342_800),
        completedAt: Date(timeIntervalSince1970: 1_742_342_860)
      )
    ]
    workspace.orderedStructuredObjectRecords = [
      structuredNoteRecord(
        id: "66666666-6666-6666-6666-666666666666",
        originPostID: "post-meeting-0001",
        ordinal: 0,
        noteType: .meetingSummary,
        body: "This body should stay in the M5 card only.",
        createdByParticipantType: .system,
        createdByParticipantID: "orbit-system"
      )
    ]

    let surfaceItems = workspace.activeStructuredNotesAndDecisionsSurfaceItems
    let note = try #require(surfaceItems.first)

    guard case let .note(surface) = note.content else {
      Issue.record("Expected a note surface item.")
      return
    }

    #expect(note.createdByDisplayName == "Orbit System")
    #expect(surface.noteType == .meetingSummary)
    #expect(surface.presentation == .meetingSummaryReference)
  }

  @Test
  func decisionEvidenceResolvesInLinkedReferenceOrderAndKeepsMissingFallbacks() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-message-0002"
    workspace.orderedStructuredObjectRecords = [
      structuredDecisionRecord(
        id: "77777777-7777-7777-7777-777777777777",
        originPostID: "post-message-0002",
        ordinal: 0,
        title: "Use the canonical ordered lane",
        linkedReferenceIDs: [
          UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
          UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        ],
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      ),
      structuredReferenceRecord(
        id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        originPostID: "post-message-0002",
        ordinal: 1,
        target: "Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md",
        title: "Orbit vision"
      ),
      structuredReferenceRecord(
        id: "88888888-8888-8888-8888-888888888888",
        originPostID: "post-message-0002",
        ordinal: 2,
        target: "Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md",
        title: "Runtime model RFC"
      ),
    ]

    let surfaceItems = workspace.activeStructuredNotesAndDecisionsSurfaceItems
    let decision = try #require(surfaceItems.first)

    guard case let .decision(surface) = decision.content else {
      Issue.record("Expected a decision surface item.")
      return
    }

    #expect(surface.evidence.map(\.title) == [
      "Runtime model RFC",
      "Missing linked evidence",
      "Orbit vision",
    ])
    #expect(surface.evidence.map(\.isMissing) == [false, true, false])
  }

  @Test
  func decisionEvidencePreservesDuplicateLinkedReferencesWithStableOrdinalIDs() throws {
    let duplicatedReferenceID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let missingReferenceID = UUID(uuidString: "34343434-3434-3434-3434-343434343434")!

    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-message-0003"
    workspace.orderedStructuredObjectRecords = [
      structuredDecisionRecord(
        id: "abababab-abab-abab-abab-abababababab",
        originPostID: "post-message-0003",
        ordinal: 0,
        title: "Keep evidence order exact",
        linkedReferenceIDs: [
          duplicatedReferenceID,
          duplicatedReferenceID,
          missingReferenceID,
        ],
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      ),
      structuredReferenceRecord(
        id: duplicatedReferenceID.uuidString,
        originPostID: "post-message-0003",
        ordinal: 1,
        target: "Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md",
        title: "Runtime model RFC"
      ),
    ]

    let surfaceItems = workspace.activeStructuredNotesAndDecisionsSurfaceItems
    let decision = try #require(surfaceItems.first)

    guard case let .decision(surface) = decision.content else {
      Issue.record("Expected a decision surface item.")
      return
    }

    #expect(surface.evidence.map(\.title) == [
      "Runtime model RFC",
      "Runtime model RFC",
      "Missing linked evidence",
    ])
    #expect(surface.evidence.map(\.id) == [
      "\(duplicatedReferenceID.uuidString)-0",
      "\(duplicatedReferenceID.uuidString)-1",
      "\(missingReferenceID.uuidString)-2",
    ])
  }

  @Test
  func structuredNotesAndDecisionsCardVisibilityHonorsEditableAndEmptyStates() {
    let sampleItem = OrbitStructuredNotesAndDecisionsSurfaceItem(
      id: "note:sample",
      createdByDisplayName: "AJ",
      createdAt: Date(timeIntervalSince1970: 1_742_342_900),
      content: .note(
        OrbitStructuredNoteSurface(
          noteType: .brief,
          body: "Visible note",
          presentation: .fullBody
        )
      )
    )

    #expect(
      OrbitPanelView.shouldShowStructuredNotesAndDecisionsCard(
        isMeetingCompletionEditable: false,
        surfaceItems: [sampleItem]
      ) == true
    )
    #expect(
      OrbitPanelView.shouldShowStructuredNotesAndDecisionsCard(
        isMeetingCompletionEditable: true,
        surfaceItems: [sampleItem]
      ) == false
    )
    #expect(
      OrbitPanelView.shouldShowStructuredNotesAndDecisionsCard(
        isMeetingCompletionEditable: false,
        surfaceItems: []
      ) == false
    )
  }
}

private func structuredNoteRecord(
  id: String,
  originPostID: String,
  ordinal: Int,
  noteType: OrbitNoteType,
  body: String,
  createdByParticipantType: OrbitParticipantAuthorType,
  createdByParticipantID: String
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "note:\(id)",
    originPostID: originPostID,
    structuredObjectType: .note,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal)),
    object: .note(
      OrbitNoteRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        noteType: noteType,
        body: body,
        createdByParticipantType: createdByParticipantType,
        createdByParticipantID: createdByParticipantID,
        createdAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal))
      )
    )
  )
}

private func structuredDecisionRecord(
  id: String,
  originPostID: String,
  ordinal: Int,
  title: String,
  linkedReferenceIDs: [UUID],
  createdByParticipantType: OrbitParticipantAuthorType,
  createdByParticipantID: String
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "decision:\(id)",
    originPostID: originPostID,
    structuredObjectType: .decision,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal)),
    object: .decision(
      OrbitDecisionRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        title: title,
        body: "Keep notes and decisions inspectable without reopening M5.",
        decisionState: .adopted,
        rationale: "Structured objects keep the important context durable.",
        tradeoffs: "Adds one more card to the room surface.",
        dissent: "None recorded.",
        linkedReferenceIDs: linkedReferenceIDs,
        createdByParticipantType: createdByParticipantType,
        createdByParticipantID: createdByParticipantID,
        createdAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal))
      )
    )
  )
}

private func structuredReferenceRecord(
  id: String,
  originPostID: String,
  ordinal: Int,
  target: String,
  title: String? = nil
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "reference:\(id)",
    originPostID: originPostID,
    structuredObjectType: .reference,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal)),
    object: .reference(
      OrbitReferenceRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        referenceType: .doc,
        target: target,
        title: title,
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue,
        createdAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal))
      )
    )
  )
}

private func structuredArtifactRecord(
  id: String,
  originPostID: String,
  ordinal: Int
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "artifact:\(id)",
    originPostID: originPostID,
    structuredObjectType: .artifact,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal)),
    object: .artifact(
      OrbitArtifactRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        artifactType: .report,
        storageRef: "reports/\(id).md",
        title: "Artifact \(id)",
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue,
        createdAt: Date(timeIntervalSince1970: 1_742_342_700 + Double(ordinal))
      )
    )
  )
}
