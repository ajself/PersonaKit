import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitServerRoomProjectionTests {
  @Test
  func projectionBuildsBelievableOrbitWorkspaceFromCanonicalSnapshot() {
    let snapshot = sampleSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)

    #expect(workspace.id == "orbit")
    #expect(workspace.displayName == "Orbit")
    #expect(workspace.purpose == "Primary Orbit room")
    #expect(workspace.participants.map(\.id).sorted() == ["aj", "proddoc", "samwise"])
    #expect(workspace.activeThread?.title == "Orbit room")
    #expect(workspace.activeThread?.interactionMode == .lightweightMeeting)
    #expect(workspace.activeThread?.messages.count == 3)
    #expect(workspace.activationRecords.count == 2)
  }

  @Test
  func projectionPreservesSpeakerMeaningAcrossCanonicalAuthors() {
    let snapshot = sampleSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)
    let messages = workspace.activeThread?.messages ?? []

    #expect(messages[0].speakerParticipantID == OrbitParticipantID.aj.rawValue)
    #expect(messages[0].kind == .user)
    #expect(messages[1].speakerParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(messages[1].kind == .participantResponse)
    #expect(messages[2].speakerParticipantID == OrbitParticipantID.prodDoc.rawValue)
    #expect(messages[2].kind == .participantResponse)
  }

  @Test
  func projectionRestoresAddressingAndActivationTraceFromCanonicalSnapshot() {
    let snapshot = sampleSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)
    let messages = workspace.activeThread?.messages ?? []

    #expect(messages[0].addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue)
    #expect(messages[1].addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue)
    #expect(messages[2].addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue)
    #expect(workspace.activationRecords.map(\.participantID).sorted() == [OrbitParticipantID.prodDoc.rawValue, OrbitParticipantID.samwise.rawValue])
    #expect(workspace.activationRecords.allSatisfy { $0.triggerSource == .meetingInvocation })
    #expect(workspace.activationContractSnapshots.count == 2)
    #expect(workspace.activationContractSnapshots.first?.reviewGateIDs == ["intent:partner-sync-review"])
  }

  @Test
  func projectionCarriesPersistedGroupsIntoWorkspaceModel() {
    let snapshot = sampleSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)

    #expect(workspace.teams.map(\.slug) == ["founding-group"])
    #expect(workspace.squads.map(\.slug) == ["command-center-feedback-squad"])
    #expect(workspace.workspacePersonaMemberships.count == 3)
  }

  @Test
  func projectionRestoresActivationFailureEvidenceFromCanonicalPostEvents() {
    let snapshot = sampleFailureSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)

    #expect(workspace.activationFailureRecords.count == 1)
    #expect(workspace.activationFailureRecords.first?.failureReason == .missingDirective)
    #expect(workspace.activationFailureRecords.first?.systemEventBody.contains("blocked the activation") == true)
    #expect(workspace.activeThread?.messages.last?.kind == .systemEvent)
  }

  @Test
  func projectionRestoresLatestFailedTurnTargetAndModeFromFailurePayload() {
    let snapshot = sampleLatestDirectFailureSnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)
    let messages = workspace.activeThread?.messages ?? []
    let latestUserMessage = messages.last(where: { $0.kind == .user })

    #expect(workspace.activeThread?.interactionMode == .directMessage)
    #expect(latestUserMessage?.addressedParticipantID == OrbitParticipantID.prodDoc.rawValue)
    #expect(workspace.activationFailureRecords.last?.triggerSource == .directAddress)
  }

  @Test
  func projectionRestoresMeetingPromotionAttemptEvidenceFromCanonicalPostEvents() {
    let snapshot = sampleSnapshot()
    let postID = snapshot.room.post.id
    let threadID = snapshot.room.thread.id
    let attemptPostEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
      payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MeetingPromotionEventPayload(
          initiatedByParticipantID: "aj",
          addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
          addressedTargetReferenceID: "founding-group",
          targetDisplayName: "Founding Group",
          meetingType: OrbitMeetingType.team.rawValue,
          title: "Founding Group Meeting",
          memberWorkspacePersonaIDs: [
            UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          ]
        )
      ),
      createdAt: Date(timeIntervalSince1970: 1_742_342_470)
    )
    let promotedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        teams: snapshot.room.teams,
        squads: snapshot.room.squads,
        workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
        post: snapshot.room.post,
        thread: snapshot.room.thread,
        messages: snapshot.room.messages,
        postParticipants: snapshot.room.postParticipants,
        postEvents: snapshot.room.postEvents + [attemptPostEvent],
        personaActivations: snapshot.room.personaActivations,
        agentRuns: snapshot.room.agentRuns
      ),
      replayCursor: snapshot.replayCursor
    )

    let workspace = OrbitServerRoomProjection.workspace(from: promotedSnapshot)

    #expect(workspace.meetingPromotionRecords.count == 1)
    #expect(workspace.meetingPromotionRecords.first?.outcome == .attempted)
    #expect(workspace.meetingPromotionRecords.first?.addressedTargetReferenceID == "founding-group")
    #expect(workspace.meetingPromotionRecords.first?.memberWorkspacePersonaIDs.count == 2)
  }

  @Test
  func projectionRestoresMeetingPromotionFailureEvidenceFromCanonicalPostEvents() {
    let snapshot = sampleSnapshot()
    let postID = snapshot.room.post.id
    let threadID = snapshot.room.thread.id
    let systemMessageID = UUID(uuidString: "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb")!
    let failurePostEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "11111111-aaaa-bbbb-cccc-111111111111")!,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionFailed.rawValue,
      payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MeetingPromotionEventPayload(
          initiatedByParticipantID: "aj",
          addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
          addressedTargetReferenceID: "founding-group",
          targetDisplayName: "Founding Group",
          meetingType: OrbitMeetingType.team.rawValue,
          title: "Founding Group Meeting",
          memberWorkspacePersonaIDs: [
            UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
          ],
          failure: OrbitPhase1MeetingPromotionFailurePayload(
            systemEventMessageID: systemMessageID,
            systemEventBody: "Orbit meeting promotion failed",
            detail: "The operation could not be completed."
          )
        )
      ),
      createdAt: Date(timeIntervalSince1970: 1_742_342_471)
    )
    let systemMessage = OrbitMessageRecord(
      id: systemMessageID,
      postID: postID,
      threadID: threadID,
      authorType: .system,
      authorID: "orbit-system",
      body: "Orbit meeting promotion failed",
      messageFormat: .plainText,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_471),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_471)
    )
    let promotedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        teams: snapshot.room.teams,
        squads: snapshot.room.squads,
        workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
        post: snapshot.room.post,
        thread: snapshot.room.thread,
        messages: snapshot.room.messages + [systemMessage],
        postParticipants: snapshot.room.postParticipants,
        postEvents: snapshot.room.postEvents + [failurePostEvent],
        personaActivations: snapshot.room.personaActivations,
        agentRuns: snapshot.room.agentRuns
      ),
      replayCursor: snapshot.replayCursor
    )

    let workspace = OrbitServerRoomProjection.workspace(from: promotedSnapshot)

    #expect(workspace.meetingPromotionRecords.count == 1)
    #expect(workspace.meetingPromotionRecords.first?.outcome == .failed)
    #expect(
      workspace.meetingPromotionFailureRecordForSystemEvent(systemMessageID.uuidString)?.detail
        == "The operation could not be completed."
    )
  }

  @Test
  func projectionRestoresMeetingOutputRecordsFromCanonicalRuntimeTruth() {
    let snapshot = sampleSnapshot()
    let meetingPostID = UUID(uuidString: "16161616-1616-1616-1616-161616161616")!
    let meetingThreadID = UUID(uuidString: "17171717-1717-1717-1717-171717171717")!
    let participantID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let participantRecordID = UUID(uuidString: "18181818-1818-1818-1818-181818181818")!
    let completedAt = Date(timeIntervalSince1970: 1_742_342_540)
    let meetingSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        teams: snapshot.room.teams,
        squads: snapshot.room.squads,
        workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
        post: OrbitPostRecord(
          id: meetingPostID,
          workspaceID: snapshot.room.workspace.id,
          channelID: snapshot.room.channel.id,
          postType: .meeting,
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          title: "Founding Group Meeting",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500)
        ),
        thread: OrbitThreadRecord(
          id: meetingThreadID,
          postID: meetingPostID,
          status: .open,
          lastActivityAt: completedAt,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500)
        ),
        messages: [],
        postParticipants: [
          OrbitPostParticipantRecord(
            id: participantRecordID,
            postID: meetingPostID,
            participantType: .workspacePersona,
            participantID: participantID.uuidString,
            joinedAt: Date(timeIntervalSince1970: 1_742_342_500),
            participationMode: .active
          )
        ],
        notes: [
          OrbitNoteRecord(
            id: UUID(uuidString: "19191919-1919-1919-1919-191919191919")!,
            postID: meetingPostID,
            noteType: .meetingSummary,
            body: "Meeting output shell completed.",
            createdByParticipantType: .system,
            createdByParticipantID: "orbit-system",
            createdAt: Date(timeIntervalSince1970: 1_742_342_500)
          )
        ],
        decisions: [
          OrbitDecisionRecord(
            id: UUID(uuidString: "20202020-2020-2020-2020-202020202020")!,
            postID: meetingPostID,
            title: "Ship packet 4 shell",
            body: "Keep the completion slice bounded.",
            decisionState: .adopted,
            createdByParticipantType: .user,
            createdByParticipantID: "aj",
            createdAt: completedAt
          )
        ],
        references: [
          OrbitReferenceRecord(
            id: UUID(uuidString: "21212121-2121-2121-2121-212121212121")!,
            postID: meetingPostID,
            referenceType: .doc,
            target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
            title: "Packet scope",
            createdByParticipantType: .user,
            createdByParticipantID: "aj",
            createdAt: completedAt.addingTimeInterval(0.001)
          )
        ],
        meetingOutputState: OrbitMeetingOutputStateRecord(
          postID: meetingPostID,
          outcomeState: .decisionRecorded,
          recordedByParticipantType: .user,
          recordedByParticipantID: "aj",
          recordedAt: completedAt
        ),
        meetingOpenQuestions: [
          OrbitMeetingOpenQuestionRecord(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            postID: meetingPostID,
            body: "How should post-completion edits work?",
            createdByParticipantType: .user,
            createdByParticipantID: "aj",
            createdAt: completedAt
          )
        ],
        meetingState: OrbitMeetingStateRecord(
          postID: meetingPostID,
          meetingType: .team,
          status: .completed,
          startedByParticipantType: .user,
          startedByParticipantID: "aj",
          startedAt: Date(timeIntervalSince1970: 1_742_342_500),
          completedAt: completedAt
        ),
        meetingMembers: [
          OrbitMeetingMemberRecord(
            id: UUID(uuidString: "23232323-2323-2323-2323-232323232323")!,
            meetingPostID: meetingPostID,
            postParticipantID: participantRecordID,
            participationRole: .contributor,
            selectedReason: "Selected from the founding group scope.",
            joinedAt: Date(timeIntervalSince1970: 1_742_342_500)
          )
        ]
      ),
      replayCursor: snapshot.replayCursor
    )

    let workspace = OrbitServerRoomProjection.workspace(from: meetingSnapshot)

    #expect(workspace.activePostID == meetingPostID.uuidString)
    #expect(workspace.activeMeetingSummaryRecord?.body == "Meeting output shell completed.")
    #expect(workspace.activeMeetingStatusRecord?.status == .completed)
    #expect(workspace.activeMeetingOutcomeRecord?.outcomeState == .decisionRecorded)
    #expect(workspace.activeMeetingDecisionRecord?.title == "Ship packet 4 shell")
    #expect(workspace.activeMeetingOpenQuestionRecords.map(\.body) == [
      "How should post-completion edits work?"
    ])
    #expect(workspace.activeMeetingReferenceRecords.first?.referenceType == .doc)
    #expect(workspace.activeMeetingMemberRecords.first?.participantID == OrbitParticipantID.samwise.rawValue)
  }

  @Test
  func projectionRestoresOriginThreadContinuityFromCanonicalPostLinks() {
    let snapshot = sampleSnapshot()
    let meetingPostID = UUID(uuidString: "12121212-3434-5656-7878-909090909090")!
    let linkedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        teams: snapshot.room.teams,
        squads: snapshot.room.squads,
        workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
        post: snapshot.room.post,
        thread: snapshot.room.thread,
        messages: snapshot.room.messages,
        postParticipants: snapshot.room.postParticipants,
        postLinks: [
          OrbitPostLinkRecord(
            id: UUID(uuidString: "13131313-3434-5656-7878-909090909090")!,
            fromPostID: snapshot.room.post.id,
            toPostID: meetingPostID,
            linkType: .promotion,
            createdAt: Date(timeIntervalSince1970: 1_742_342_472)
          )
        ],
        postEvents: snapshot.room.postEvents,
        personaActivations: snapshot.room.personaActivations,
        agentRuns: snapshot.room.agentRuns
      ),
      replayCursor: snapshot.replayCursor
    )

    let workspace = OrbitServerRoomProjection.workspace(from: linkedSnapshot)
    let continuityRecord = workspace.meetingContinuityRecords.first

    #expect(workspace.meetingContinuityRecords.count == 1)
    #expect(continuityRecord?.currentPerspective == .originThread)
    #expect(continuityRecord?.originPostID == snapshot.room.post.id.uuidString)
    #expect(continuityRecord?.promotedMeetingPostID == meetingPostID.uuidString)
    #expect(continuityRecord?.currentPostID == snapshot.room.post.id.uuidString)
    #expect(continuityRecord?.linkedPostID == meetingPostID.uuidString)
  }

  @Test
  func projectionBuildsOrderedStructuredObjectRecordsFromCanonicalAttachmentOrder() {
    let snapshot = sampleSnapshot()
    let postID = UUID(uuidString: "31313131-3131-3131-3131-313131313131")!
    let noteID = UUID(uuidString: "41414141-4141-4141-4141-414141414141")!
    let decisionID = UUID(uuidString: "42424242-4242-4242-4242-424242424242")!
    let referenceID = UUID(uuidString: "43434343-4343-4343-4343-434343434343")!
    let artifactID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let createdAt = Date(timeIntervalSince1970: 1_742_342_700)
    let mixedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        teams: snapshot.room.teams,
        squads: snapshot.room.squads,
        workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
        post: OrbitPostRecord(
          id: postID,
          workspaceID: snapshot.room.workspace.id,
          channelID: snapshot.room.channel.id,
          postType: .message,
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          title: "Mixed structured attachments",
          status: .active,
          createdAt: createdAt
        ),
        thread: OrbitThreadRecord(
          id: UUID(uuidString: "51515151-5151-5151-5151-515151515151")!,
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
            noteType: .brief,
            body: "Narrative context",
            createdByParticipantType: .user,
            createdByParticipantID: "aj",
            createdAt: createdAt
          )
        ],
        decisions: [
          OrbitDecisionRecord(
            id: decisionID,
            postID: postID,
            title: "Adopt canonical attachment ordering",
            body: "Projection should read mixed objects through one ordered model.",
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
      ),
      replayCursor: snapshot.replayCursor
    )

    let workspace = OrbitServerRoomProjection.workspace(from: mixedSnapshot)

    #expect(workspace.activeStructuredPostObjectRecords.map(\.structuredObjectType) == [
      .artifact,
      .note,
      .decision,
      .reference,
    ])
    #expect(workspace.activeStructuredPostObjectRecords.map(\.structuredObjectID) == [
      artifactID.uuidString,
      noteID.uuidString,
      decisionID.uuidString,
      referenceID.uuidString,
    ])
  }

  @Test
  func projectionRestoresPromotedMeetingContinuityFromCanonicalPostLinks() {
    let snapshot = sampleSnapshot()
    let originPostID = snapshot.room.post.id
    let promotedPostID = UUID(uuidString: "14141414-3434-5656-7878-909090909090")!
    let promotedThreadID = UUID(uuidString: "15151515-3434-5656-7878-909090909090")!
    let linkedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        teams: snapshot.room.teams,
        squads: snapshot.room.squads,
        workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
        post: OrbitPostRecord(
          id: promotedPostID,
          workspaceID: snapshot.room.workspace.id,
          channelID: snapshot.room.channel.id,
          postType: .meeting,
          createdByParticipantType: .user,
          createdByParticipantID: "aj",
          title: "Founding Group Meeting",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_472)
        ),
        thread: OrbitThreadRecord(
          id: promotedThreadID,
          postID: promotedPostID,
          status: .open,
          lastActivityAt: Date(timeIntervalSince1970: 1_742_342_472),
          createdAt: Date(timeIntervalSince1970: 1_742_342_472)
        ),
        messages: [],
        postParticipants: snapshot.room.postParticipants.map { participant in
          OrbitPostParticipantRecord(
            id: participant.id,
            postID: promotedPostID,
            participantType: participant.participantType,
            participantID: participant.participantID,
            joinedAt: participant.joinedAt,
            leftAt: participant.leftAt,
            participationMode: participant.participationMode
          )
        },
        postLinks: [
          OrbitPostLinkRecord(
            id: UUID(uuidString: "16161616-3434-5656-7878-909090909090")!,
            fromPostID: originPostID,
            toPostID: promotedPostID,
            linkType: .promotion,
            createdAt: Date(timeIntervalSince1970: 1_742_342_472)
          )
        ],
        meetingState: OrbitMeetingStateRecord(
          postID: promotedPostID,
          meetingType: .team,
          status: .created,
          startedByParticipantType: .user,
          startedByParticipantID: "aj",
          startedAt: Date(timeIntervalSince1970: 1_742_342_472)
        ),
        meetingMembers: [],
        postEvents: [],
        personaActivations: [],
        agentRuns: []
      ),
      replayCursor: snapshot.replayCursor
    )

    let workspace = OrbitServerRoomProjection.workspace(from: linkedSnapshot)
    let continuityRecord = workspace.meetingContinuityRecords.first

    #expect(workspace.meetingContinuityRecords.count == 1)
    #expect(continuityRecord?.currentPerspective == .promotedMeeting)
    #expect(continuityRecord?.originPostID == originPostID.uuidString)
    #expect(continuityRecord?.promotedMeetingPostID == promotedPostID.uuidString)
    #expect(continuityRecord?.currentPostID == promotedPostID.uuidString)
    #expect(continuityRecord?.linkedPostID == originPostID.uuidString)
  }

  @Test
  func projectionRestoresMeetingSummaryShellFromCanonicalNotes() {
    let snapshot = sampleMeetingSummarySnapshot()

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)
    let summaryRecord = workspace.meetingSummaryRecords.first

    #expect(workspace.meetingSummaryRecords.count == 1)
    #expect(summaryRecord?.postID == snapshot.room.post.id.uuidString)
    #expect(summaryRecord?.postTitle == "Founding Group Meeting")
    #expect(summaryRecord?.body == "Summary pending.")
    #expect(summaryRecord?.createdByParticipantType == .system)
    #expect(summaryRecord?.createdByParticipantID == "orbit-system")
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let foundingGroupTeamID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let feedbackSquadID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let t0 = Date(timeIntervalSince1970: 1_742_342_400)

    let room = OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: t0
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: t0
      ),
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: t0
        ),
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          workspaceID: workspaceID,
          personaTemplateID: "venture-product-steward",
          displayName: "ProdDoc",
          status: .active,
          createdAt: t0.addingTimeInterval(1)
        ),
      ],
      teams: [
        OrbitTeamRecord(
          id: foundingGroupTeamID,
          workspaceID: workspaceID,
          slug: "founding-group",
          name: "Founding Group",
          purpose: "Seeded first team target.",
          createdAt: t0
        )
      ],
      squads: [
        OrbitSquadRecord(
          id: feedbackSquadID,
          workspaceID: workspaceID,
          teamID: foundingGroupTeamID,
          slug: "command-center-feedback-squad",
          name: "Command Center Feedback Squad",
          purpose: "Focused feedback lane.",
          createdAt: t0.addingTimeInterval(2)
        )
      ],
      workspacePersonaMemberships: [
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          workspacePersonaID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
          teamID: foundingGroupTeamID,
          roleInGroup: "trusted-partner",
          createdAt: t0.addingTimeInterval(3)
        ),
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          workspacePersonaID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          teamID: foundingGroupTeamID,
          roleInGroup: "product-steward",
          createdAt: t0.addingTimeInterval(4)
        ),
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
          workspacePersonaID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          squadID: feedbackSquadID,
          roleInGroup: "reviewer",
          createdAt: t0.addingTimeInterval(5)
        ),
      ],
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .meeting,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: t0
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: t0.addingTimeInterval(60),
        createdAt: t0
      ),
      messages: [
        OrbitMessageRecord(
          id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Founding group, regroup.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: t0.addingTimeInterval(10),
          updatedAt: t0.addingTimeInterval(10)
        ),
        OrbitMessageRecord(
          id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
          postID: postID,
          threadID: threadID,
          authorType: .workspacePersona,
          authorID: "workspace-persona-orbit-samwise",
          replyToMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          body: "Samwise is here.",
          messageFormat: .markdown,
          state: .completed,
          createdAt: t0.addingTimeInterval(20),
          updatedAt: t0.addingTimeInterval(20)
        ),
        OrbitMessageRecord(
          id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
          postID: postID,
          threadID: threadID,
          authorType: .workspacePersona,
          authorID: "workspace-persona-orbit-proddoc",
          replyToMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          body: "ProdDoc is here.",
          messageFormat: .markdown,
          state: .completed,
          createdAt: t0.addingTimeInterval(30),
          updatedAt: t0.addingTimeInterval(30)
        ),
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: t0.addingTimeInterval(5),
          participationMode: .active
        ),
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-proddoc",
          joinedAt: t0.addingTimeInterval(6),
          participationMode: .active
        ),
      ],
      postEvents: [
        OrbitPostEventRecord(
          id: UUID(uuidString: "18181818-1818-1818-1818-181818181818")!,
          postID: postID,
          threadID: threadID,
          eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
          payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
            OrbitPhase1ActivationEventPayload(
              activationID: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
              initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
              initiatedByParticipantID: "aj",
              triggerMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
              addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
              addressedTargetReferenceID: OrbitAddressTargetID.foundingGroup.rawValue,
              resolvedWorkspacePersonaInstanceID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
              responseMode: OrbitCanonicalResponseMode.lightweightMeeting.rawValue,
              agentRunID: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
              runnerKind: "local-bridge",
              agentRunStatus: OrbitAgentRunStatus.completed.rawValue,
              agentRunStartedAt: t0.addingTimeInterval(20),
              agentRunCompletedAt: t0.addingTimeInterval(20),
              contract: OrbitPhase1ResolvedContractPayload(
                directiveID: "maintain-partner-sync-and-handoffs",
                directiveSource: OrbitDirectiveSource.participantDefault.rawValue,
                kitIDs: ["trusted-partner-core"],
                authorizedSkillIDs: ["codex-cli"],
                requiredSkillIDs: ["codex-cli"],
                reviewGateIDs: ["intent:partner-sync-review"]
              )
            )
          ),
          createdAt: t0.addingTimeInterval(20)
        ),
        OrbitPostEventRecord(
          id: UUID(uuidString: "19191919-1919-1919-1919-191919191919")!,
          postID: postID,
          threadID: threadID,
          eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
          payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
            OrbitPhase1ActivationEventPayload(
              activationID: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
              initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
              initiatedByParticipantID: "aj",
              triggerMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
              addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
              addressedTargetReferenceID: OrbitAddressTargetID.foundingGroup.rawValue,
              resolvedWorkspacePersonaInstanceID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
              responseMode: OrbitCanonicalResponseMode.lightweightMeeting.rawValue,
              agentRunID: UUID(uuidString: "17171717-1717-1717-1717-171717171717")!,
              runnerKind: "local-bridge",
              agentRunStatus: OrbitAgentRunStatus.completed.rawValue,
              agentRunStartedAt: t0.addingTimeInterval(30),
              agentRunCompletedAt: t0.addingTimeInterval(30),
              contract: OrbitPhase1ResolvedContractPayload(
                directiveID: "run-venture-product-planning",
                directiveSource: OrbitDirectiveSource.participantDefault.rawValue,
                kitIDs: ["venture-product-core"],
                authorizedSkillIDs: ["codex-cli"],
                requiredSkillIDs: ["codex-cli"],
                stopPointIDs: ["Pause for AJ review before execution handoff."],
                reviewGateIDs: ["intent:plan-macos-feature-delivery"]
              )
            )
          ),
          createdAt: t0.addingTimeInterval(30)
        ),
      ],
      personaActivations: [
        OrbitPersonaActivationRecord(
          id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
          initiatedByParticipantType: .user,
          initiatedByParticipantID: "aj",
          workspaceID: workspaceID,
          channelID: channelID,
          originPostID: postID,
          originThreadID: threadID,
          triggerMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          addressedTargetKind: .team,
          addressedTargetReferenceID: OrbitAddressTargetID.foundingGroup.rawValue,
          resolvedWorkspacePersonaInstanceID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
          responseMode: .lightweightMeeting,
          createdAt: t0.addingTimeInterval(20)
        ),
        OrbitPersonaActivationRecord(
          id: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
          initiatedByParticipantType: .user,
          initiatedByParticipantID: "aj",
          workspaceID: workspaceID,
          channelID: channelID,
          originPostID: postID,
          originThreadID: threadID,
          triggerMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          addressedTargetKind: .team,
          addressedTargetReferenceID: OrbitAddressTargetID.foundingGroup.rawValue,
          resolvedWorkspacePersonaInstanceID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
          responseMode: .lightweightMeeting,
          createdAt: t0.addingTimeInterval(30)
        ),
      ],
      agentRuns: [
        OrbitAgentRunRecord(
          id: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
          personaActivationID: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
          runnerKind: "local-bridge",
          status: .completed,
          startedAt: t0.addingTimeInterval(20),
          completedAt: t0.addingTimeInterval(20)
        ),
        OrbitAgentRunRecord(
          id: UUID(uuidString: "17171717-1717-1717-1717-171717171717")!,
          personaActivationID: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
          runnerKind: "local-bridge",
          status: .completed,
          startedAt: t0.addingTimeInterval(30),
          completedAt: t0.addingTimeInterval(30)
        ),
      ]
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!,
        lastEventCreatedAt: t0.addingTimeInterval(60)
      )
    )
  }

  private func sampleFailureSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let snapshot = sampleSnapshot()
    let t1 = Date(timeIntervalSince1970: 1_742_342_490)
    let postID = snapshot.room.post.id
    let threadID = snapshot.room.thread.id
    let blockedSystemMessage = OrbitMessageRecord(
      id: UUID(uuidString: "20202020-2020-2020-2020-202020202020")!,
      postID: postID,
      threadID: threadID,
      authorType: .system,
      authorID: "orbit-system",
      replyToMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
      body: "Orbit blocked the activation because the collaborator has no resolved directive for this checkpoint.",
      messageFormat: .plainText,
      state: .completed,
      createdAt: t1,
      updatedAt: t1
    )
    let failurePostEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "21212121-2121-2121-2121-212121212121")!,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
      payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activationID: nil,
          initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
          initiatedByParticipantID: "aj",
          triggerMessageID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          failure: OrbitPhase1ActivationFailurePayload(
            addressedTargetID: OrbitParticipantID.prodDoc.rawValue,
            participantID: OrbitParticipantID.prodDoc.rawValue,
            workspacePersonaID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!.uuidString,
            personaTemplateID: "venture-product-steward",
            directiveID: nil,
            triggerSource: OrbitActivationTriggerSource.directAddress.rawValue,
            systemEventMessageID: blockedSystemMessage.id,
            requiredSkillIDs: ["codex-cli"],
            authorizedSkillIDs: ["codex-cli"],
            failureReason: OrbitActivationFailureReason.missingDirective.rawValue,
            systemEventBody: blockedSystemMessage.body
          ),
          reason: OrbitActivationFailureReason.missingDirective.rawValue
        )
      ),
      createdAt: t1
    )
    let room = OrbitPhase1RoomSnapshot(
      workspace: snapshot.room.workspace,
      channel: snapshot.room.channel,
      workspacePersonas: snapshot.room.workspacePersonas,
      teams: snapshot.room.teams,
      squads: snapshot.room.squads,
      workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
      post: snapshot.room.post,
      thread: snapshot.room.thread,
      messages: snapshot.room.messages + [blockedSystemMessage],
      postParticipants: snapshot.room.postParticipants,
      postEvents: snapshot.room.postEvents + [failurePostEvent],
      personaActivations: snapshot.room.personaActivations,
      agentRuns: snapshot.room.agentRuns
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: snapshot.replayCursor
    )
  }

  private func sampleLatestDirectFailureSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let snapshot = sampleSnapshot()
    let t1 = Date(timeIntervalSince1970: 1_742_342_520)
    let postID = snapshot.room.post.id
    let threadID = snapshot.room.thread.id
    let failedUserMessage = OrbitMessageRecord(
      id: UUID(uuidString: "30303030-3030-3030-3030-303030303030")!,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "ProdDoc, pressure-test the checkpoint.",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: t1,
      updatedAt: t1
    )
    let blockedSystemMessage = OrbitMessageRecord(
      id: UUID(uuidString: "31313131-3131-3131-3131-313131313131")!,
      postID: postID,
      threadID: threadID,
      authorType: .system,
      authorID: "orbit-system",
      replyToMessageID: failedUserMessage.id,
      body: "Orbit blocked the activation because the collaborator has no resolved directive for this checkpoint.",
      messageFormat: .plainText,
      state: .completed,
      createdAt: t1.addingTimeInterval(1),
      updatedAt: t1.addingTimeInterval(1)
    )
    let failurePostEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "32323232-3232-3232-3232-323232323232")!,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
      payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activationID: nil,
          initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
          initiatedByParticipantID: "aj",
          triggerMessageID: failedUserMessage.id,
          failure: OrbitPhase1ActivationFailurePayload(
            addressedTargetID: OrbitParticipantID.prodDoc.rawValue,
            participantID: OrbitParticipantID.prodDoc.rawValue,
            workspacePersonaID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!.uuidString,
            personaTemplateID: "venture-product-steward",
            directiveID: nil,
            triggerSource: OrbitActivationTriggerSource.directAddress.rawValue,
            systemEventMessageID: blockedSystemMessage.id,
            requiredSkillIDs: ["codex-cli"],
            authorizedSkillIDs: ["codex-cli"],
            failureReason: OrbitActivationFailureReason.missingDirective.rawValue,
            systemEventBody: blockedSystemMessage.body
          ),
          reason: OrbitActivationFailureReason.missingDirective.rawValue
        )
      ),
      createdAt: t1.addingTimeInterval(1)
    )
    let room = OrbitPhase1RoomSnapshot(
      workspace: snapshot.room.workspace,
      channel: snapshot.room.channel,
      workspacePersonas: snapshot.room.workspacePersonas,
      teams: snapshot.room.teams,
      squads: snapshot.room.squads,
      workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
      post: snapshot.room.post,
      thread: snapshot.room.thread,
      messages: snapshot.room.messages + [failedUserMessage, blockedSystemMessage],
      postParticipants: snapshot.room.postParticipants,
      postEvents: snapshot.room.postEvents + [failurePostEvent],
      personaActivations: snapshot.room.personaActivations,
      agentRuns: snapshot.room.agentRuns
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: snapshot.replayCursor
    )
  }

  private func sampleMeetingSummarySnapshot() -> OrbitPhase1RealtimeSnapshot {
    let snapshot = sampleSnapshot()
    let promotedPostID = UUID(uuidString: "18181818-1818-1818-1818-181818181818")!
    let promotedThreadID = UUID(uuidString: "19191919-1919-1919-1919-191919191919")!
    let t1 = Date(timeIntervalSince1970: 1_742_342_518)

    let room = OrbitPhase1RoomSnapshot(
      workspace: snapshot.room.workspace,
      channel: snapshot.room.channel,
      workspacePersonas: snapshot.room.workspacePersonas,
      teams: snapshot.room.teams,
      squads: snapshot.room.squads,
      workspacePersonaMemberships: snapshot.room.workspacePersonaMemberships,
      post: OrbitPostRecord(
        id: promotedPostID,
        workspaceID: snapshot.room.workspace.id,
        channelID: snapshot.room.channel.id,
        postType: .meeting,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Founding Group Meeting",
        status: .active,
        createdAt: t1
      ),
      thread: OrbitThreadRecord(
        id: promotedThreadID,
        postID: promotedPostID,
        status: .open,
        lastActivityAt: t1,
        createdAt: t1
      ),
      messages: [],
      postParticipants: snapshot.room.postParticipants.map { participant in
        OrbitPostParticipantRecord(
          id: participant.id,
          postID: promotedPostID,
          participantType: participant.participantType,
          participantID: participant.participantID,
          joinedAt: participant.joinedAt,
          leftAt: participant.leftAt,
          participationMode: participant.participationMode
        )
      },
      notes: [
        OrbitNoteRecord(
          id: UUID(uuidString: "20202020-2020-2020-2020-202020202021")!,
          postID: promotedPostID,
          noteType: .meetingSummary,
          body: "Summary pending.",
          createdByParticipantType: .system,
          createdByParticipantID: "orbit-system",
          createdAt: t1
        )
      ],
      meetingState: OrbitMeetingStateRecord(
        postID: promotedPostID,
        meetingType: .team,
        status: .created,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: t1
      ),
      meetingMembers: [],
      postEvents: [],
      personaActivations: [],
      agentRuns: []
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: snapshot.replayCursor
    )
  }
}
