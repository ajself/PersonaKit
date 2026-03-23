import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

@MainActor
struct OrbitStructuredReferencesAndArtifactsPresentationTests {
  @Test
  func surfaceItemsPreserveCanonicalOrderAcrossMixedEvidenceAttachments() {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-message-evidence-0001"
    workspace.orderedStructuredObjectRecords = [
      evidenceNoteRecord(
        id: "11111111-aaaa-bbbb-cccc-111111111111",
        originPostID: "post-message-evidence-0001",
        ordinal: 0
      ),
      evidenceReferenceRecord(
        id: "22222222-aaaa-bbbb-cccc-222222222222",
        originPostID: "post-message-evidence-0001",
        ordinal: 1,
        referenceType: .doc,
        target: "Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/README.md",
        title: "M6 milestone packet",
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      ),
      evidenceArtifactRecord(
        id: "33333333-aaaa-bbbb-cccc-333333333333",
        originPostID: "post-message-evidence-0001",
        ordinal: 2,
        artifactType: .report,
        storageRef: "reports/m6-p4-slice.md",
        title: "M6 P4 Slice",
        createdByParticipantType: .workspacePersona,
        createdByParticipantID: "workspace-persona-orbit-samwise"
      ),
      evidenceDecisionRecord(
        id: "44444444-aaaa-bbbb-cccc-444444444444",
        originPostID: "post-message-evidence-0001",
        ordinal: 3
      ),
      evidenceReferenceRecord(
        id: "55555555-aaaa-bbbb-cccc-555555555555",
        originPostID: "post-message-evidence-0001",
        ordinal: 4,
        referenceType: .file,
        target: "Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md",
        title: nil,
        createdByParticipantType: .system,
        createdByParticipantID: "orbit-system"
      ),
    ]

    let surfaceItems = workspace.activeStructuredReferencesAndArtifactsSurfaceItems

    #expect(surfaceItems.map(\.id) == [
      "reference:22222222-aaaa-bbbb-cccc-222222222222",
      "artifact:33333333-aaaa-bbbb-cccc-333333333333",
      "reference:55555555-aaaa-bbbb-cccc-555555555555",
    ])
    #expect(surfaceItems.map(\.createdByDisplayName) == [
      "AJ",
      "Samwise",
      "Orbit System",
    ])
  }

  @Test
  func meetingReferencesBecomeCompactRowsWhenMirroredByMeetingOutputs() throws {
    let referenceID = UUID(uuidString: "66666666-aaaa-bbbb-cccc-666666666666")!

    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-meeting-evidence-0001"
    workspace.meetingStatusRecords = [
      OrbitMeetingStatusRecord(
        id: "meeting-status-evidence-0001",
        postID: "post-meeting-evidence-0001",
        meetingType: .team,
        status: .completed,
        startedByParticipantType: .user,
        startedByParticipantID: OrbitParticipantID.aj.rawValue,
        startedAt: Date(timeIntervalSince1970: 1_742_343_000),
        completedAt: Date(timeIntervalSince1970: 1_742_343_060)
      )
    ]
    workspace.meetingReferenceRecords = [
      OrbitMeetingReferenceRecord(
        id: referenceID.uuidString,
        postID: "post-meeting-evidence-0001",
        referenceType: .doc,
        target: "Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Packet-01-Freeze-Object-Definitions.md",
        title: "Object freeze",
        createdAt: Date(timeIntervalSince1970: 1_742_343_060)
      )
    ]
    workspace.orderedStructuredObjectRecords = [
      evidenceReferenceRecord(
        id: referenceID.uuidString,
        originPostID: "post-meeting-evidence-0001",
        ordinal: 0,
        referenceType: .doc,
        target: "Docs/Orbit/Planning/Milestones/M6-Structured-Post-Objects-And-Decisions/Packet-01-Freeze-Object-Definitions.md",
        title: "Object freeze",
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      )
    ]

    let surfaceItems = workspace.activeStructuredReferencesAndArtifactsSurfaceItems
    let reference = try #require(surfaceItems.first)

    guard case let .reference(surface) = reference.content else {
      Issue.record("Expected a reference surface item.")
      return
    }

    #expect(surface.presentation == .meetingOutputsReference)
    #expect(reference.createdByDisplayName == "AJ")
  }

  @Test
  func meetingReferencesWithoutMirroredMeetingOutputsStayFullRows() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-meeting-evidence-0002"
    workspace.meetingStatusRecords = [
      OrbitMeetingStatusRecord(
        id: "meeting-status-evidence-0002",
        postID: "post-meeting-evidence-0002",
        meetingType: .team,
        status: .completed,
        startedByParticipantType: .user,
        startedByParticipantID: OrbitParticipantID.aj.rawValue,
        startedAt: Date(timeIntervalSince1970: 1_742_343_100),
        completedAt: Date(timeIntervalSince1970: 1_742_343_160)
      )
    ]
    workspace.meetingReferenceRecords = [
      OrbitMeetingReferenceRecord(
        id: "meeting-reference-evidence-0002",
        postID: "post-meeting-evidence-0002",
        referenceType: .doc,
        target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
        title: "Different legacy row",
        createdAt: Date(timeIntervalSince1970: 1_742_343_160)
      )
    ]
    workspace.orderedStructuredObjectRecords = [
      evidenceReferenceRecord(
        id: "77777777-aaaa-bbbb-cccc-777777777777",
        originPostID: "post-meeting-evidence-0002",
        ordinal: 0,
        referenceType: .doc,
        target: "Docs/Orbit/Vision/orbit-platform-vision-and-system-design.md",
        title: "Orbit vision",
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      )
    ]

    let surfaceItems = workspace.activeStructuredReferencesAndArtifactsSurfaceItems
    let reference = try #require(surfaceItems.first)

    guard case let .reference(surface) = reference.content else {
      Issue.record("Expected a reference surface item.")
      return
    }

    #expect(surface.presentation == .fullMetadata)
  }

  @Test
  func meetingArtifactsRemainFullRows() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-meeting-evidence-0003"
    workspace.meetingStatusRecords = [
      OrbitMeetingStatusRecord(
        id: "meeting-status-evidence-0003",
        postID: "post-meeting-evidence-0003",
        meetingType: .team,
        status: .completed,
        startedByParticipantType: .user,
        startedByParticipantID: OrbitParticipantID.aj.rawValue,
        startedAt: Date(timeIntervalSince1970: 1_742_343_200),
        completedAt: Date(timeIntervalSince1970: 1_742_343_260)
      )
    ]
    workspace.orderedStructuredObjectRecords = [
      evidenceArtifactRecord(
        id: "88888888-aaaa-bbbb-cccc-888888888888",
        originPostID: "post-meeting-evidence-0003",
        ordinal: 0,
        artifactType: .report,
        storageRef: "reports/meeting-closeout.md",
        title: "Meeting closeout",
        createdByParticipantType: .system,
        createdByParticipantID: "orbit-system"
      )
    ]

    let surfaceItems = workspace.activeStructuredReferencesAndArtifactsSurfaceItems
    let artifact = try #require(surfaceItems.first)

    guard case let .artifact(surface) = artifact.content else {
      Issue.record("Expected an artifact surface item.")
      return
    }

    #expect(surface.title == "Meeting closeout")
    #expect(surface.storageRef == "reports/meeting-closeout.md")
    #expect(artifact.createdByDisplayName == "Orbit System")
  }

  @Test
  func structuredReferencesAndArtifactsCardVisibilityHonorsEditableAndEmptyStates() {
    let sampleItem = OrbitStructuredReferencesAndArtifactsSurfaceItem(
      id: "reference:sample",
      createdByDisplayName: "AJ",
      createdAt: Date(timeIntervalSince1970: 1_742_343_300),
      content: .reference(
        OrbitStructuredReferenceSurface(
          referenceType: .doc,
          title: "Sample reference",
          target: "Docs/Orbit/README.md",
          presentation: .fullMetadata
        )
      )
    )

    #expect(
      OrbitPanelView.shouldShowStructuredReferencesAndArtifactsCard(
        isMeetingCompletionEditable: false,
        surfaceItems: [sampleItem]
      ) == true
    )
    #expect(
      OrbitPanelView.shouldShowStructuredReferencesAndArtifactsCard(
        isMeetingCompletionEditable: true,
        surfaceItems: [sampleItem]
      ) == false
    )
    #expect(
      OrbitPanelView.shouldShowStructuredReferencesAndArtifactsCard(
        isMeetingCompletionEditable: false,
        surfaceItems: []
      ) == false
    )
  }

  @Test
  func typeLabelsAreHumanizedAndTitleFallbacksStayStable() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.activePostID = "post-message-evidence-0004"
    workspace.orderedStructuredObjectRecords = [
      evidenceReferenceRecord(
        id: "99999999-aaaa-bbbb-cccc-999999999999",
        originPostID: "post-message-evidence-0004",
        ordinal: 0,
        referenceType: .externalNote,
        target: "notes/research-packet.md",
        title: nil,
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue
      ),
      evidenceArtifactRecord(
        id: "aaaaaaaa-aaaa-bbbb-cccc-aaaaaaaaaaaa",
        originPostID: "post-message-evidence-0004",
        ordinal: 1,
        artifactType: .codeOutput,
        storageRef: "outputs/runtime-proof.txt",
        title: nil,
        createdByParticipantType: .workspacePersona,
        createdByParticipantID: "workspace-persona-orbit-samwise"
      ),
    ]

    let surfaceItems = workspace.activeStructuredReferencesAndArtifactsSurfaceItems
    let reference = try #require(surfaceItems.first)
    let artifact = try #require(surfaceItems.last)

    guard case let .reference(referenceSurface) = reference.content else {
      Issue.record("Expected a reference surface item.")
      return
    }

    guard case let .artifact(artifactSurface) = artifact.content else {
      Issue.record("Expected an artifact surface item.")
      return
    }

    #expect(referenceSurface.title == "notes/research-packet.md")
    #expect(artifactSurface.title == "outputs/runtime-proof.txt")
    #expect(referenceSurface.referenceType.displayText == "External Note")
    #expect(artifactSurface.artifactType.displayText == "Code Output")
  }
}

private func evidenceReferenceRecord(
  id: String,
  originPostID: String,
  ordinal: Int,
  referenceType: OrbitReferenceType,
  target: String,
  title: String?,
  createdByParticipantType: OrbitParticipantAuthorType,
  createdByParticipantID: String
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "reference:\(id)",
    originPostID: originPostID,
    structuredObjectType: .reference,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal)),
    object: .reference(
      OrbitReferenceRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        referenceType: referenceType,
        target: target,
        title: title,
        createdByParticipantType: createdByParticipantType,
        createdByParticipantID: createdByParticipantID,
        createdAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal))
      )
    )
  )
}

private func evidenceArtifactRecord(
  id: String,
  originPostID: String,
  ordinal: Int,
  artifactType: OrbitArtifactType,
  storageRef: String,
  title: String?,
  createdByParticipantType: OrbitParticipantAuthorType,
  createdByParticipantID: String
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "artifact:\(id)",
    originPostID: originPostID,
    structuredObjectType: .artifact,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal)),
    object: .artifact(
      OrbitArtifactRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        artifactType: artifactType,
        storageRef: storageRef,
        title: title,
        createdByParticipantType: createdByParticipantType,
        createdByParticipantID: createdByParticipantID,
        createdAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal))
      )
    )
  )
}

private func evidenceNoteRecord(
  id: String,
  originPostID: String,
  ordinal: Int
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "note:\(id)",
    originPostID: originPostID,
    structuredObjectType: .note,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal)),
    object: .note(
      OrbitNoteRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        noteType: .brief,
        body: "Narrative context",
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue,
        createdAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal))
      )
    )
  )
}

private func evidenceDecisionRecord(
  id: String,
  originPostID: String,
  ordinal: Int
) -> OrbitStructuredPostObjectRecord {
  OrbitStructuredPostObjectRecord(
    id: "decision:\(id)",
    originPostID: originPostID,
    structuredObjectType: .decision,
    structuredObjectID: id,
    attachmentOrdinal: ordinal,
    attachedAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal)),
    object: .decision(
      OrbitDecisionRecord(
        id: UUID(uuidString: id)!,
        postID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        title: "Keep packet scope bounded",
        body: "Notes and decisions remain separate from evidence rows.",
        decisionState: .adopted,
        createdByParticipantType: .user,
        createdByParticipantID: OrbitParticipantID.aj.rawValue,
        createdAt: Date(timeIntervalSince1970: 1_742_343_000 + Double(ordinal))
      )
    )
  )
}
