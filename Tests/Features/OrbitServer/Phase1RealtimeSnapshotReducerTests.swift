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
}
