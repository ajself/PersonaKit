import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1RealtimeSnapshotReducerTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  private let baselineCursorID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

  @Test
  func reducerAppendsMessageAndUpdatesThreadActivity() throws {
    let initial = sampleSnapshot()
    let newMessageID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let messageDate = Date(timeIntervalSince1970: 1_742_342_520)
    let threadDate = Date(timeIntervalSince1970: 1_742_342_521)
    let events = [
      OrbitPhase1RealtimeEventEnvelope(
        id: newMessageID,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .messageCreated,
        createdAt: messageDate,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1MessageCreatedPayload(
            messageID: newMessageID,
            postID: postID,
            threadID: threadID,
            authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
            authorID: "workspace-persona-orbit-samwise",
            body: "Server-backed reply",
            messageFormat: OrbitMessageFormat.markdown.rawValue,
            state: OrbitMessageState.completed.rawValue,
            createdAt: messageDate,
            updatedAt: messageDate,
            replyToMessageID: nil
          )
        )
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .threadActivityUpdated,
        createdAt: threadDate,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1ThreadActivityUpdatedPayload(
            threadID: threadID,
            lastActivityAt: threadDate
          )
        )
      ),
    ]

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(events: events, to: initial)

    #expect(reduced.room.messages.count == 2)
    #expect(reduced.room.messages.last?.body == "Server-backed reply")
    #expect(reduced.room.thread.lastActivityAt == threadDate)
    #expect(reduced.replayCursor.lastEventID == events.last?.id)
  }

  @Test
  func reducerAddsParticipantAndActivationFailureEvent() throws {
    let initial = sampleSnapshot()
    let participantDate = Date(timeIntervalSince1970: 1_742_342_520)
    let failureEventID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    let events = [
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .participantJoined,
        createdAt: participantDate,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1ParticipantJoinedPayload(
            participantType: OrbitParticipantAuthorType.workspacePersona.rawValue,
            participantID: "workspace-persona-orbit-proddoc",
            joinedAt: participantDate,
            participationMode: OrbitParticipationMode.active.rawValue
          )
        )
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: failureEventID,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .activationFailed,
        createdAt: participantDate.addingTimeInterval(1),
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1ActivationEventPayload(
            activationID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
            responseMode: nil,
            reason: "stale-client"
          )
        )
      ),
    ]

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(events: events, to: initial)

    #expect(reduced.room.postParticipants.count == 2)
    #expect(reduced.room.postEvents.last?.id == failureEventID)
    #expect(reduced.room.postEvents.last?.eventType == OrbitPhase1RealtimeEventCategory.activationFailed.rawValue)
  }

  @Test
  func reducerRestoresActivationAndAgentRunFromResolvedActivationEvent() throws {
    let initial = sampleSnapshot()
    let activationID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    let agentRunID = UUID(uuidString: "abababab-abab-abab-abab-abababababab")!
    let workspacePersonaID = UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!
    let triggerMessageID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let activationDate = Date(timeIntervalSince1970: 1_742_342_520)
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: activationID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .activationResolved,
      createdAt: activationDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activationID: activationID,
          initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
          initiatedByParticipantID: "aj",
          triggerMessageID: triggerMessageID,
          addressedTargetKind: OrbitAddressedTargetKind.collaborator.rawValue,
          addressedTargetReferenceID: workspacePersonaID.uuidString,
          resolvedWorkspacePersonaInstanceID: workspacePersonaID,
          responseMode: OrbitCanonicalResponseMode.directAddress.rawValue,
          agentRunID: agentRunID,
          runnerKind: "local-bridge",
          agentRunStatus: OrbitAgentRunStatus.completed.rawValue,
          agentRunStartedAt: activationDate,
          agentRunCompletedAt: activationDate
        )
      )
    )

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(
      events: [event],
      to: initial
    )

    #expect(reduced.room.personaActivations.count == 1)
    #expect(reduced.room.personaActivations.first?.id == activationID)
    #expect(reduced.room.personaActivations.first?.resolvedWorkspacePersonaInstanceID == workspacePersonaID)
    #expect(reduced.room.agentRuns.count == 1)
    #expect(reduced.room.agentRuns.first?.id == agentRunID)
    #expect(reduced.room.postEvents.last?.id == activationID)
  }

  @Test
  func reducerPreservesMeetingRuntimeRecordsAcrossThreadUpdates() throws {
    let initial = sampleMeetingSnapshot()
    let messageDate = Date(timeIntervalSince1970: 1_742_342_520)
    let threadDate = Date(timeIntervalSince1970: 1_742_342_521)
    let events = [
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "abababab-abab-abab-abab-abababababab")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .messageCreated,
        createdAt: messageDate,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1MessageCreatedPayload(
            messageID: UUID(uuidString: "bcbcbcbc-bcbc-bcbc-bcbc-bcbcbcbcbcbc")!,
            postID: postID,
            threadID: threadID,
            authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
            authorID: "workspace-persona-orbit-proddoc",
            body: "Meeting record should survive this append.",
            messageFormat: OrbitMessageFormat.markdown.rawValue,
            state: OrbitMessageState.completed.rawValue,
            createdAt: messageDate,
            updatedAt: messageDate,
            replyToMessageID: nil
          )
        )
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdce")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .threadActivityUpdated,
        createdAt: threadDate,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1ThreadActivityUpdatedPayload(
            threadID: threadID,
            lastActivityAt: threadDate
          )
        )
      ),
    ]

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(events: events, to: initial)

    #expect(reduced.room.meetingState == initial.room.meetingState)
    #expect(reduced.room.meetingMembers == initial.room.meetingMembers)
  }

  @Test
  func reducerPreservesPromotionContinuityLinksAcrossReplay() throws {
    let initial = sampleMeetingSnapshotWithContinuityLink()
    let messageDate = Date(timeIntervalSince1970: 1_742_342_530)
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "91919191-9191-9191-9191-919191919191")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: messageDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: UUID(uuidString: "92929292-9292-9292-9292-929292929292")!,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
          authorID: "workspace-persona-orbit-samwise",
          body: "Continuity should survive replay.",
          messageFormat: OrbitMessageFormat.markdown.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: messageDate,
          updatedAt: messageDate,
          replyToMessageID: nil
        )
      )
    )

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(
      events: [event],
      to: initial
    )

    #expect(reduced.room.postLinks == initial.room.postLinks)
  }

  @Test
  func reducerPreservesMeetingSummaryShellAcrossReplay() throws {
    let initial = sampleMeetingSnapshotWithSummaryShell()
    let messageDate = Date(timeIntervalSince1970: 1_742_342_531)
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "95959595-9595-9595-9595-959595959595")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: messageDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: UUID(uuidString: "96969696-9696-9696-9696-969696969696")!,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
          authorID: "workspace-persona-orbit-samwise",
          body: "Summary shell should survive replay.",
          messageFormat: OrbitMessageFormat.markdown.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: messageDate,
          updatedAt: messageDate,
          replyToMessageID: nil
        )
      )
    )

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(
      events: [event],
      to: initial
    )

    #expect(reduced.room.notes == initial.room.notes)
  }

  @Test
  func reducerReplaysMeetingCompletionBundleWithoutDroppingContinuityEvidence() throws {
    let baseline = sampleMeetingSnapshotWithSummaryShell()
    let initial = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: baseline.room.workspace,
        channel: baseline.room.channel,
        workspacePersonas: baseline.room.workspacePersonas,
        post: baseline.room.post,
        thread: baseline.room.thread,
        messages: baseline.room.messages,
        postParticipants: baseline.room.postParticipants,
        postLinks: [
          OrbitPostLinkRecord(
            id: UUID(uuidString: "98989898-9898-9898-9898-989898989898")!,
            fromPostID: UUID(uuidString: "99999999-aaaa-bbbb-cccc-dddddddddddd")!,
            toPostID: baseline.room.post.id,
            linkType: .promotion,
            createdAt: Date(timeIntervalSince1970: 1_742_342_517)
          )
        ],
        notes: baseline.room.notes,
        meetingOutputState: OrbitMeetingOutputStateRecord(
          postID: baseline.room.post.id,
          outcomeState: .pending,
          recordedByParticipantType: .system,
          recordedByParticipantID: "orbit-system",
          recordedAt: Date(timeIntervalSince1970: 1_742_342_518)
        ),
        meetingState: baseline.room.meetingState,
        meetingMembers: baseline.room.meetingMembers,
        postEvents: baseline.room.postEvents,
        personaActivations: baseline.room.personaActivations,
        agentRuns: baseline.room.agentRuns
      ),
      replayCursor: baseline.replayCursor
    )
    let completedAt = Date(timeIntervalSince1970: 1_742_342_540)
    let summaryNoteID = UUID(uuidString: "97979797-9797-9797-9797-979797979797")!
    let decisionID = UUID(uuidString: "a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1")!
    let referenceID = UUID(uuidString: "a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2")!
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .meetingOutputCommitted,
      createdAt: completedAt,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MeetingCompletionEventPayload(
          summaryNote: OrbitNoteRecord(
            id: summaryNoteID,
            postID: postID,
            noteType: .meetingSummary,
            body: "Meeting outputs survived replay.",
            createdByParticipantType: .system,
            createdByParticipantID: "orbit-system",
            createdAt: Date(timeIntervalSince1970: 1_742_342_518)
          ),
          meetingOutputState: OrbitMeetingOutputStateRecord(
            postID: postID,
            outcomeState: .decisionRecorded,
            recordedByParticipantType: .user,
            recordedByParticipantID: "aj",
            recordedAt: completedAt
          ),
          decision: OrbitDecisionRecord(
            id: decisionID,
            postID: postID,
            title: "Persist completion bundle",
            body: "Replay should keep summary, decision, questions, and references.",
            decisionState: .adopted,
            createdByParticipantType: .user,
            createdByParticipantID: "aj",
            createdAt: completedAt
          ),
          references: [
            OrbitReferenceRecord(
              id: referenceID,
              postID: postID,
              referenceType: .doc,
              target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
              createdByParticipantType: .user,
              createdByParticipantID: "aj",
              createdAt: completedAt.addingTimeInterval(0.001)
            )
          ],
          structuredAttachments: [
            OrbitStructuredAttachmentRecord(
              originPostID: postID,
              structuredObjectType: .reference,
              structuredObjectID: referenceID,
              attachmentOrdinal: 0,
              attachedAt: completedAt.addingTimeInterval(0.001)
            ),
            OrbitStructuredAttachmentRecord(
              originPostID: postID,
              structuredObjectType: .note,
              structuredObjectID: summaryNoteID,
              attachmentOrdinal: 1,
              attachedAt: Date(timeIntervalSince1970: 1_742_342_518)
            ),
            OrbitStructuredAttachmentRecord(
              originPostID: postID,
              structuredObjectType: .decision,
              structuredObjectID: decisionID,
              attachmentOrdinal: 2,
              attachedAt: completedAt
            ),
          ],
          meetingOpenQuestions: [
            OrbitMeetingOpenQuestionRecord(
              id: UUID(uuidString: "a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3")!,
              postID: postID,
              body: "Should edits reopen completed meetings?",
              createdByParticipantType: .user,
              createdByParticipantID: "aj",
              createdAt: completedAt
            )
          ],
          meetingState: OrbitMeetingStateRecord(
            postID: postID,
            meetingType: .team,
            status: .completed,
            startedByParticipantType: .user,
            startedByParticipantID: "aj",
            startedAt: initial.room.meetingState?.startedAt ?? completedAt,
            completedAt: completedAt
          ),
          threadLastActivityAt: completedAt
        )
      )
    )

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(
      events: [event],
      to: initial
    )

    #expect(reduced.room.notes.first?.body == "Meeting outputs survived replay.")
    #expect(reduced.room.meetingOutputState?.outcomeState == .decisionRecorded)
    #expect(reduced.room.decisions.count == 1)
    #expect(reduced.room.references.count == 1)
    #expect(reduced.room.meetingOpenQuestions.count == 1)
    #expect(reduced.room.meetingState?.status == .completed)
    #expect(reduced.room.structuredAttachments.map(\.structuredObjectType) == [
      .reference,
      .note,
      .decision,
    ])
    #expect(reduced.room.orderedStructuredObjects.map(\.id) == [
      referenceID,
      summaryNoteID,
      decisionID,
    ])
    #expect(reduced.room.postLinks == initial.room.postLinks)
    #expect(reduced.room.postEvents.last?.eventType == OrbitPhase1RealtimeEventCategory.meetingOutputCommitted.rawValue)
    #expect(reduced.room.thread.lastActivityAt == completedAt)
  }

  @Test
  func reducerSynthesizesStructuredAttachmentsForLegacyMeetingCompletionPayloads() throws {
    let initial = sampleMeetingSnapshotWithSummaryShell()
    let completedAt = Date(timeIntervalSince1970: 1_742_342_541)
    let decisionID = UUID(uuidString: "b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1")!
    let referenceID = UUID(uuidString: "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2")!
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b0b0b0")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .meetingOutputCommitted,
      createdAt: completedAt,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MeetingCompletionEventPayload(
          summaryNote: OrbitNoteRecord(
            id: initial.room.notes[0].id,
            postID: postID,
            noteType: .meetingSummary,
            body: "Legacy payload without attachment list.",
            createdByParticipantType: .system,
            createdByParticipantID: "orbit-system",
            createdAt: initial.room.notes[0].createdAt
          ),
          meetingOutputState: OrbitMeetingOutputStateRecord(
            postID: postID,
            outcomeState: .decisionRecorded,
            recordedByParticipantType: .user,
            recordedByParticipantID: "aj",
            recordedAt: completedAt
          ),
          decision: OrbitDecisionRecord(
            id: decisionID,
            postID: postID,
            title: "Legacy completion",
            body: "Replay should still synthesize attachment order.",
            decisionState: .adopted,
            createdByParticipantType: .user,
            createdByParticipantID: "aj",
            createdAt: completedAt
          ),
          references: [
            OrbitReferenceRecord(
              id: referenceID,
              postID: postID,
              referenceType: .doc,
              target: "Docs/Orbit/RFCs/RFC-0002-Collaboration-Runtime-and-Memory-Data-Model.md",
              createdByParticipantType: .user,
              createdByParticipantID: "aj",
              createdAt: completedAt.addingTimeInterval(0.001)
            )
          ],
          meetingOpenQuestions: [],
          meetingState: OrbitMeetingStateRecord(
            postID: postID,
            meetingType: .team,
            status: .completed,
            startedByParticipantType: .user,
            startedByParticipantID: "aj",
            startedAt: initial.room.meetingState?.startedAt ?? completedAt,
            completedAt: completedAt
          ),
          threadLastActivityAt: completedAt
        )
      )
    )

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(
      events: [event],
      to: initial
    )

    #expect(reduced.room.structuredAttachments.map(\.structuredObjectType) == [
      .note,
      .decision,
      .reference,
    ])
    #expect(reduced.room.orderedStructuredObjects.map(\.id) == [
      initial.room.notes[0].id,
      decisionID,
      referenceID,
    ])
  }

  @Test
  func reducerAddsMeetingPromotionAttemptAndFailureEvidence() throws {
    let initial = sampleSnapshot()
    let failureMessageID = UUID(uuidString: "dededede-dede-dede-dede-dededededede")!
    let eventDate = Date(timeIntervalSince1970: 1_742_342_520)
    let failurePayload = OrbitPhase1MeetingPromotionEventPayload(
      initiatedByParticipantID: "aj",
      addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
      addressedTargetReferenceID: "founding-group",
      targetDisplayName: "Founding Group",
      meetingType: OrbitMeetingType.team.rawValue,
      title: "Founding Group Meeting",
      memberWorkspacePersonaIDs: [
        UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!,
      ],
      failure: OrbitPhase1MeetingPromotionFailurePayload(
        systemEventMessageID: failureMessageID,
        systemEventBody: "Orbit meeting promotion failed",
        detail: "The operation could not be completed."
      )
    )
    let events = [
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "abababab-abab-abab-abab-abababababab")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .meetingPromotionAttempted,
        createdAt: eventDate,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1MeetingPromotionEventPayload(
            initiatedByParticipantID: "aj",
            addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
            addressedTargetReferenceID: "founding-group",
            targetDisplayName: "Founding Group",
            meetingType: OrbitMeetingType.team.rawValue,
            title: "Founding Group Meeting",
            memberWorkspacePersonaIDs: [
              UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!,
            ]
          )
        )
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: failureMessageID,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .messageCreated,
        createdAt: eventDate.addingTimeInterval(1),
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1MessageCreatedPayload(
            messageID: failureMessageID,
            postID: postID,
            threadID: threadID,
            authorType: OrbitParticipantAuthorType.system.rawValue,
            authorID: "orbit-system",
            body: "Orbit meeting promotion failed",
            messageFormat: OrbitMessageFormat.plainText.rawValue,
            state: OrbitMessageState.completed.rawValue,
            createdAt: eventDate.addingTimeInterval(1),
            updatedAt: eventDate.addingTimeInterval(1),
            replyToMessageID: nil
          )
        )
      ),
      OrbitPhase1RealtimeEventEnvelope(
        id: UUID(uuidString: "bcbcbcbc-bcbc-bcbc-bcbc-bcbcbcbcbcbc")!,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .meetingPromotionFailed,
        createdAt: eventDate.addingTimeInterval(1),
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(failurePayload)
      ),
    ]

    let reduced = try OrbitPhase1RealtimeSnapshotReducer.applying(events: events, to: initial)

    #expect(reduced.room.messages.last?.id == failureMessageID)
    #expect(
      reduced.room.postEvents.map(\.eventType) == [
        OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
        OrbitPhase1RealtimeEventCategory.meetingPromotionFailed.rawValue,
      ]
    )
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let room = OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_405)
        )
      ],
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: Date(timeIntervalSince1970: 1_742_342_460),
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      messages: [
        OrbitMessageRecord(
          id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Orbit room bootstrapped.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        ),
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        )
      ],
      postEvents: []
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: baselineCursorID,
        lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
      )
    )
  }

  private func sampleMeetingSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let baseline = sampleSnapshot()
    let participantIDs = baseline.room.postParticipants.map(\.id)

    let room = OrbitPhase1RoomSnapshot(
      workspace: baseline.room.workspace,
      channel: baseline.room.channel,
      workspacePersonas: baseline.room.workspacePersonas,
      post: OrbitPostRecord(
        id: baseline.room.post.id,
        workspaceID: baseline.room.post.workspaceID,
        channelID: baseline.room.post.channelID,
        postType: .meeting,
        createdByParticipantType: baseline.room.post.createdByParticipantType,
        createdByParticipantID: baseline.room.post.createdByParticipantID,
        title: baseline.room.post.title,
        status: baseline.room.post.status,
        createdAt: baseline.room.post.createdAt,
        archivedAt: baseline.room.post.archivedAt
      ),
      thread: baseline.room.thread,
      messages: baseline.room.messages,
      postParticipants: baseline.room.postParticipants,
      notes: baseline.room.notes,
      meetingOutputState: OrbitMeetingOutputStateRecord(
        postID: baseline.room.post.id,
        outcomeState: .pending,
        recordedByParticipantType: .system,
        recordedByParticipantID: "orbit-system",
        recordedAt: baseline.room.post.createdAt
      ),
      meetingState: OrbitMeetingStateRecord(
        postID: baseline.room.post.id,
        meetingType: .team,
        status: .active,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: baseline.room.post.createdAt
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: UUID(uuidString: "dededede-dede-dede-dede-dededededede")!,
          meetingPostID: baseline.room.post.id,
          postParticipantID: participantIDs[0],
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: baseline.room.postParticipants[0].joinedAt
        )
      ],
      postEvents: baseline.room.postEvents,
      personaActivations: baseline.room.personaActivations,
      agentRuns: baseline.room.agentRuns
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: baseline.replayCursor
    )
  }

  private func sampleMeetingSnapshotWithContinuityLink() -> OrbitPhase1RealtimeSnapshot {
    let baseline = sampleMeetingSnapshot()

    return OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: baseline.room.workspace,
        channel: baseline.room.channel,
        workspacePersonas: baseline.room.workspacePersonas,
        post: baseline.room.post,
        thread: baseline.room.thread,
        messages: baseline.room.messages,
        postParticipants: baseline.room.postParticipants,
        postLinks: [
          OrbitPostLinkRecord(
            id: UUID(uuidString: "93939393-9393-9393-9393-939393939393")!,
            fromPostID: UUID(uuidString: "94949494-9494-9494-9494-949494949494")!,
            toPostID: baseline.room.post.id,
            linkType: .promotion,
            createdAt: Date(timeIntervalSince1970: 1_742_342_519)
          )
        ],
        notes: baseline.room.notes,
        meetingOutputState: baseline.room.meetingOutputState,
        meetingState: baseline.room.meetingState,
        meetingMembers: baseline.room.meetingMembers,
        postEvents: baseline.room.postEvents,
        personaActivations: baseline.room.personaActivations,
        agentRuns: baseline.room.agentRuns
      ),
      replayCursor: baseline.replayCursor
    )
  }

  private func sampleMeetingSnapshotWithSummaryShell() -> OrbitPhase1RealtimeSnapshot {
    let baseline = sampleMeetingSnapshot()

    return OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: baseline.room.workspace,
        channel: baseline.room.channel,
        workspacePersonas: baseline.room.workspacePersonas,
        post: baseline.room.post,
        thread: baseline.room.thread,
        messages: baseline.room.messages,
        postParticipants: baseline.room.postParticipants,
        notes: [
          OrbitNoteRecord(
            id: UUID(uuidString: "97979797-9797-9797-9797-979797979797")!,
            postID: baseline.room.post.id,
            noteType: .meetingSummary,
            body: "Summary pending.",
            createdByParticipantType: .system,
            createdByParticipantID: "orbit-system",
            createdAt: Date(timeIntervalSince1970: 1_742_342_518)
          )
        ],
        meetingOutputState: baseline.room.meetingOutputState,
        meetingState: baseline.room.meetingState,
        meetingMembers: baseline.room.meetingMembers,
        postEvents: baseline.room.postEvents,
        personaActivations: baseline.room.personaActivations,
        agentRuns: baseline.room.agentRuns
      ),
      replayCursor: baseline.replayCursor
    )
  }
}
