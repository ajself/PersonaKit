import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitServerBackedRoomCoordinatorTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func connectBootstrapsProjectedWorkspaceFromServerTransport() async throws {
    var coordinator = OrbitServerBackedRoomCoordinator()

    try await coordinator.connect(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      transport: StubTransport(
        connectResponse: .bootstrap(sampleSession(), sampleSnapshot()),
        pollResponse: .noChange(sampleSnapshot().replayCursorSession)
      )
    )

    #expect(coordinator.roomState.projectedWorkspace?.displayName == "Orbit")
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.count == 1)
    #expect(coordinator.roomState.session?.scope.workspaceSlug == "orbit")
  }

  @Test
  func pollAdvancesProjectedWorkspaceFromReplayEvents() async throws {
    let snapshot = sampleSnapshot()
    let messageID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let replayEvent = OrbitPhase1RealtimeEventEnvelope(
      id: messageID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_500),
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: messageID,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
          authorID: "workspace-persona-orbit-samwise",
          body: "Server-backed replay response",
          messageFormat: OrbitMessageFormat.markdown.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_500),
          replyToMessageID: nil
        )
      )
    )
    let updatedSession = OrbitPhase1RealtimeSession(
      scope: sampleSession().scope,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: replayEvent.id,
        lastEventCreatedAt: replayEvent.createdAt
      ),
      connectedAt: sampleSession().connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_500)
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: snapshot,
        session: sampleSession(),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: snapshot)
      )
    )

    try await coordinator.poll(
      transport: StubTransport(
        connectResponse: .bootstrap(sampleSession(), snapshot),
        pollResponse: .replay(updatedSession, [replayEvent])
      )
    )

    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body == "Server-backed replay response")
    #expect(coordinator.roomState.session?.replayCursor.lastEventID == replayEvent.id)
  }

  @Test
  func pollReplaysSystemMessageMutationIntoProjectedWorkspace() async throws {
    let snapshot = sampleSnapshot()
    let systemMessageID = UUID(uuidString: "56565656-5656-5656-5656-565656565656")!
    let systemMessageDate = Date(timeIntervalSince1970: 1_742_342_500)
    let threadDate = Date(timeIntervalSince1970: 1_742_342_501)
    let messageEvent = OrbitPhase1RealtimeEventEnvelope(
      id: systemMessageID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: systemMessageDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: systemMessageID,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.system.rawValue,
          authorID: "orbit-system",
          body: "Orbit marked the room as resynced after the transient gateway drop.",
          messageFormat: OrbitMessageFormat.plainText.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: systemMessageDate,
          updatedAt: systemMessageDate,
          replyToMessageID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        )
      )
    )
    let threadEvent = threadActivityEvent(
      id: UUID(uuidString: "57575757-5757-5757-5757-575757575757")!,
      createdAt: threadDate,
      lastActivityAt: threadDate
    )
    let updatedSession = replaySession(
      lastEventID: threadEvent.id,
      lastEventCreatedAt: threadEvent.createdAt
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: snapshot,
        session: sampleSession(),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: snapshot)
      )
    )

    try await coordinator.poll(
      transport: StubTransport(
        connectResponse: .bootstrap(sampleSession(), snapshot),
        pollResponse: .replay(updatedSession, [messageEvent, threadEvent])
      )
    )

    let replayedMessage = try #require(
      coordinator.roomState.projectedWorkspace?.activeThread?.messages.last
    )
    #expect(replayedMessage.body == "Orbit marked the room as resynced after the transient gateway drop.")
    #expect(replayedMessage.kind == .systemEvent)
    #expect(coordinator.roomState.session?.replayCursor.lastEventID == threadEvent.id)
  }

  @Test
  func pollReplaysCollaboratorResponseMutationWithActivationTrace() async throws {
    let snapshot = sampleSnapshot()
    let workspacePersonaID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let responseMessageID = UUID(uuidString: "58585858-5858-5858-5858-585858585858")!
    let activationID = UUID(uuidString: "59595959-5959-5959-5959-595959595959")!
    let agentRunID = UUID(uuidString: "5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a")!
    let postEventID = UUID(uuidString: "5b5b5b5b-5b5b-5b5b-5b5b-5b5b5b5b5b5b")!
    let responseDate = Date(timeIntervalSince1970: 1_742_342_520)
    let threadDate = Date(timeIntervalSince1970: 1_742_342_521)
    let activationDate = Date(timeIntervalSince1970: 1_742_342_522)
    let messageEvent = OrbitPhase1RealtimeEventEnvelope(
      id: responseMessageID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: responseDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: responseMessageID,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
          authorID: workspacePersonaID.uuidString,
          body: "Canonical replay restored the collaborator response without losing its contract trace.",
          messageFormat: OrbitMessageFormat.markdown.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: responseDate,
          updatedAt: responseDate,
          replyToMessageID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        )
      )
    )
    let threadEvent = threadActivityEvent(
      id: UUID(uuidString: "5c5c5c5c-5c5c-5c5c-5c5c-5c5c5c5c5c5c")!,
      createdAt: threadDate,
      lastActivityAt: threadDate
    )
    let activationEvent = OrbitPhase1RealtimeEventEnvelope(
      id: postEventID,
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
          triggerMessageID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          addressedTargetKind: OrbitAddressedTargetKind.collaborator.rawValue,
          addressedTargetReferenceID: workspacePersonaID.uuidString,
          resolvedWorkspacePersonaInstanceID: workspacePersonaID,
          responseMode: OrbitCanonicalResponseMode.directAddress.rawValue,
          agentRunID: agentRunID,
          runnerKind: "local-bridge",
          agentRunStatus: OrbitAgentRunStatus.completed.rawValue,
          agentRunStartedAt: activationDate,
          agentRunCompletedAt: activationDate,
          contract: OrbitPhase1ResolvedContractPayload(
            directiveID: "maintain-partner-sync-and-handoffs",
            directiveSource: OrbitDirectiveSource.participantDefault.rawValue,
            kitIDs: ["trusted-partner-core"],
            authorizedSkillIDs: ["codex-cli"],
            requiredSkillIDs: ["codex-cli"],
            reviewGateIDs: ["intent:partner-sync-review"]
          )
        )
      )
    )
    let updatedSession = replaySession(
      lastEventID: activationEvent.id,
      lastEventCreatedAt: activationEvent.createdAt
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: snapshot,
        session: sampleSession(),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: snapshot)
      )
    )

    try await coordinator.poll(
      transport: StubTransport(
        connectResponse: .bootstrap(sampleSession(), snapshot),
        pollResponse: .replay(updatedSession, [messageEvent, threadEvent, activationEvent])
      )
    )

    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body == "Canonical replay restored the collaborator response without losing its contract trace.")
    #expect(coordinator.roomState.projectedWorkspace?.activationRecords.count == 1)
    #expect(coordinator.roomState.projectedWorkspace?.activationContractSnapshots.count == 1)
    #expect(coordinator.roomState.snapshot?.room.postEvents.last?.id == postEventID)
    #expect(coordinator.roomState.snapshot?.room.personaActivations.first?.id == activationID)
    #expect(coordinator.roomState.snapshot?.room.agentRuns.first?.id == agentRunID)
  }

  @Test
  func pollReplaysActivationFailureMutationIntoFailureRecords() async throws {
    let snapshot = sampleSnapshot()
    let systemMessageID = UUID(uuidString: "5d5d5d5d-5d5d-5d5d-5d5d-5d5d5d5d5d5d")!
    let failureEventID = UUID(uuidString: "5e5e5e5e-5e5e-5e5e-5e5e-5e5e5e5e5e5e")!
    let failureDate = Date(timeIntervalSince1970: 1_742_342_530)
    let threadDate = Date(timeIntervalSince1970: 1_742_342_531)
    let messageEvent = OrbitPhase1RealtimeEventEnvelope(
      id: systemMessageID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: failureDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: systemMessageID,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.system.rawValue,
          authorID: "orbit-system",
          body: "Orbit blocked the collaborator activation because no directive resolved for the request.",
          messageFormat: OrbitMessageFormat.plainText.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: failureDate,
          updatedAt: failureDate,
          replyToMessageID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        )
      )
    )
    let threadEvent = threadActivityEvent(
      id: UUID(uuidString: "5f5f5f5f-5f5f-5f5f-5f5f-5f5f5f5f5f5f")!,
      createdAt: threadDate,
      lastActivityAt: threadDate
    )
    let failureEvent = OrbitPhase1RealtimeEventEnvelope(
      id: failureEventID,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .activationFailed,
      createdAt: failureDate,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activationID: nil,
          initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
          initiatedByParticipantID: "aj",
          triggerMessageID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          failure: OrbitPhase1ActivationFailurePayload(
            addressedTargetID: OrbitParticipantID.samwise.rawValue,
            participantID: OrbitParticipantID.samwise.rawValue,
            workspacePersonaID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!.uuidString,
            personaTemplateID: "samwise",
            directiveID: nil,
            triggerSource: OrbitActivationTriggerSource.directAddress.rawValue,
            systemEventMessageID: systemMessageID,
            requiredSkillIDs: ["codex-cli"],
            authorizedSkillIDs: ["codex-cli"],
            failureReason: OrbitActivationFailureReason.missingDirective.rawValue,
            systemEventBody: "Orbit blocked the collaborator activation because no directive resolved for the request."
          ),
          reason: OrbitActivationFailureReason.missingDirective.rawValue
        )
      )
    )
    let updatedSession = replaySession(
      lastEventID: threadEvent.id,
      lastEventCreatedAt: threadEvent.createdAt
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: snapshot,
        session: sampleSession(),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: snapshot)
      )
    )

    try await coordinator.poll(
      transport: StubTransport(
        connectResponse: .bootstrap(sampleSession(), snapshot),
        pollResponse: .replay(updatedSession, [messageEvent, failureEvent, threadEvent])
      )
    )

    let activationFailure = try #require(
      coordinator.roomState.projectedWorkspace?.activationFailureRecords.last
    )
    #expect(activationFailure.failureReason == .missingDirective)
    #expect(activationFailure.systemEventMessageID == systemMessageID.uuidString)
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.kind == .systemEvent)
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body.contains("blocked the collaborator activation") == true)
  }

  @Test
  func reconnectCarriesForwardReplayCursorAcrossRepeatedRecoveryCycles() async throws {
    let initialSnapshot = sampleSnapshot()
    let firstRecoveryMessage = OrbitMessageRecord(
      id: UUID(uuidString: "60606060-6060-6060-6060-606060606060")!,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "Persistent transport replay restored the missed user turn after the first drop.",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_540),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_540)
    )
    let firstRecoveryMessageEvent = OrbitPhase1RealtimeEventEnvelope(
      id: firstRecoveryMessage.id,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: firstRecoveryMessage.createdAt,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: firstRecoveryMessage.id,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.user.rawValue,
          authorID: "aj",
          body: firstRecoveryMessage.body,
          messageFormat: OrbitMessageFormat.plainText.rawValue,
          state: OrbitMessageState.persisted.rawValue,
          createdAt: firstRecoveryMessage.createdAt,
          updatedAt: firstRecoveryMessage.updatedAt,
          replyToMessageID: nil
        )
      )
    )
    let firstRecoveryThreadEvent = threadActivityEvent(
      id: UUID(uuidString: "61616161-6161-6161-6161-616161616161")!,
      createdAt: Date(timeIntervalSince1970: 1_742_342_541),
      lastActivityAt: Date(timeIntervalSince1970: 1_742_342_541)
    )
    let firstRecoverySession = replaySession(
      lastEventID: firstRecoveryThreadEvent.id,
      lastEventCreatedAt: firstRecoveryThreadEvent.createdAt
    )

    let secondRecoveryMessage = collaboratorResponseMessage(
      id: UUID(uuidString: "62626262-6262-6262-6262-626262626262")!,
      authorID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!.uuidString,
      replyToMessageID: firstRecoveryMessage.id,
      body: "Persistent transport reconnected again and kept the collaborator trace attached to the same canonical turn.",
      createdAt: Date(timeIntervalSince1970: 1_742_342_542)
    )
    let secondRecoveryMessageEvent = OrbitPhase1RealtimeEventEnvelope(
      id: secondRecoveryMessage.id,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: secondRecoveryMessage.createdAt,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: secondRecoveryMessage.id,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.workspacePersona.rawValue,
          authorID: secondRecoveryMessage.authorID,
          body: secondRecoveryMessage.body,
          messageFormat: OrbitMessageFormat.markdown.rawValue,
          state: OrbitMessageState.completed.rawValue,
          createdAt: secondRecoveryMessage.createdAt,
          updatedAt: secondRecoveryMessage.updatedAt,
          replyToMessageID: firstRecoveryMessage.id
        )
      )
    )
    let secondRecoveryThreadEvent = threadActivityEvent(
      id: UUID(uuidString: "63636363-6363-6363-6363-636363636363")!,
      createdAt: Date(timeIntervalSince1970: 1_742_342_543),
      lastActivityAt: Date(timeIntervalSince1970: 1_742_342_543)
    )
    let secondRecoveryActivation = collaboratorActivation(
      id: UUID(uuidString: "64646464-6464-6464-6464-646464646464")!,
      workspacePersonaID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
      triggerMessageID: firstRecoveryMessage.id
    )
    let secondRecoveryRun = collaboratorRun(
      id: UUID(uuidString: "65656565-6565-6565-6565-656565656565")!,
      activationID: secondRecoveryActivation.id,
      startedAt: secondRecoveryMessage.createdAt
    )
    let secondRecoveryActivationEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "66666660-6666-6666-6666-666666666660")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .activationResolved,
      createdAt: Date(timeIntervalSince1970: 1_742_342_544),
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activation: secondRecoveryActivation,
          agentRun: secondRecoveryRun,
          contract: OrbitPhase1ResolvedContractPayload(
            directiveID: "maintain-partner-sync-and-handoffs",
            directiveSource: OrbitDirectiveSource.participantDefault.rawValue,
            kitIDs: ["trusted-partner-core"],
            authorizedSkillIDs: ["codex-cli"],
            requiredSkillIDs: ["codex-cli"],
            reviewGateIDs: ["intent:partner-sync-review"]
          )
        )
      )
    )
    let secondRecoverySession = replaySession(
      lastEventID: secondRecoveryActivationEvent.id,
      lastEventCreatedAt: secondRecoveryActivationEvent.createdAt
    )
    let resyncedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: initialSnapshot.room.workspace,
        channel: initialSnapshot.room.channel,
        workspacePersonas: initialSnapshot.room.workspacePersonas,
        post: initialSnapshot.room.post,
        thread: OrbitThreadRecord(
          id: initialSnapshot.room.thread.id,
          postID: initialSnapshot.room.thread.postID,
          status: initialSnapshot.room.thread.status,
          lastActivityAt: secondRecoveryActivationEvent.createdAt,
          createdAt: initialSnapshot.room.thread.createdAt,
          closedAt: initialSnapshot.room.thread.closedAt
        ),
        messages: initialSnapshot.room.messages + [firstRecoveryMessage, secondRecoveryMessage],
        postParticipants: initialSnapshot.room.postParticipants,
        postEvents: [
          OrbitPostEventRecord(
            id: secondRecoveryActivationEvent.id,
            postID: postID,
            threadID: threadID,
            eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
            payloadJSON: secondRecoveryActivationEvent.payloadJSON,
            createdAt: secondRecoveryActivationEvent.createdAt
          )
        ],
        personaActivations: [secondRecoveryActivation],
        agentRuns: [secondRecoveryRun]
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: secondRecoveryActivationEvent.id,
        lastEventCreatedAt: secondRecoveryActivationEvent.createdAt
      )
    )
    let transport = SequencedClientTransport(
      connectResponses: [
        .bootstrap(sampleSession(snapshot: initialSnapshot), initialSnapshot),
        .replay(firstRecoverySession, [firstRecoveryMessageEvent, firstRecoveryThreadEvent]),
        .replay(
          secondRecoverySession,
          [secondRecoveryMessageEvent, secondRecoveryThreadEvent, secondRecoveryActivationEvent]
        ),
        .resync(
          sampleSession(snapshot: resyncedSnapshot),
          resyncedSnapshot,
          .staleClient
        ),
      ],
      pollResponse: .noChange(sampleSession(snapshot: resyncedSnapshot))
    )
    let client = OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: StubClientRoomWriter(
        result: OrbitPhase1AppendUserMessageResult(
          snapshot: initialSnapshot.room,
          message: firstRecoveryMessage
        )
      ),
      systemWriter: StubClientSystemWriter(
        result: OrbitPhase1AppendSystemMessageResult(
          snapshot: initialSnapshot.room,
          message: OrbitMessageRecord(
            id: UUID(uuidString: "67676767-6767-6767-6767-676767676767")!,
            postID: postID,
            threadID: threadID,
            authorType: .system,
            authorID: "orbit-system",
            body: "unused",
            messageFormat: .plainText,
            state: .completed,
            createdAt: Date(timeIntervalSince1970: 1_742_342_545),
            updatedAt: Date(timeIntervalSince1970: 1_742_342_545)
          )
        )
      ),
      failureWriter: StubClientFailureWriter(
        result: activationFailureResult(
          snapshot: initialSnapshot.room,
          systemMessageBody: "unused"
        )
      ),
      collaboratorWriter: StubClientCollaboratorWriter(
        result: collaboratorResult(
          snapshot: initialSnapshot.room,
          message: secondRecoveryMessage,
          activationID: secondRecoveryActivation.id,
          workspacePersonaID: secondRecoveryActivation.resolvedWorkspacePersonaInstanceID,
          triggerMessageID: firstRecoveryMessage.id
        )
      )
    )
    var coordinator = OrbitServerBackedRoomCoordinator()

    try await coordinator.connect(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center"
      ),
      client: client
    )
    try await coordinator.reconnect(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center"
      ),
      client: client
    )
    try await coordinator.reconnect(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center"
      ),
      client: client
    )
    try await coordinator.reconnect(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center"
      ),
      client: client
    )

    let connectRequests = await transport.connectRequests

    #expect(connectRequests.count == 4)
    #expect(connectRequests[0].cursor == nil)
    #expect(connectRequests[1].cursor == initialSnapshot.replayCursor)
    #expect(connectRequests[2].cursor == firstRecoverySession.replayCursor)
    #expect(connectRequests[3].cursor == secondRecoverySession.replayCursor)
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.map(\.body) == [
      "Orbit room bootstrapped.",
      firstRecoveryMessage.body,
      secondRecoveryMessage.body,
    ])
    #expect(coordinator.roomState.projectedWorkspace?.activationRecords.count == 1)
    #expect(coordinator.roomState.projectedWorkspace?.activationContractSnapshots.count == 1)
    #expect(coordinator.roomState.session?.replayCursor == resyncedSnapshot.replayCursor)
  }

  @Test
  func pollDoesNothingWhenNoSessionExists() async throws {
    var coordinator = OrbitServerBackedRoomCoordinator()

    try await coordinator.poll(
      transport: StubTransport(
        connectResponse: .bootstrap(sampleSession(), sampleSnapshot()),
        pollResponse: .noChange(sampleSnapshot().replayCursorSession)
      )
    )

    #expect(coordinator.roomState.projectedWorkspace == nil)
    #expect(coordinator.roomState.session == nil)
  }

  @Test
  func appendConversationTurnRefreshesProjectedWorkspaceFromServerClient() async throws {
    let initialSnapshot = sampleSnapshot()
    let updatedMessage = OrbitMessageRecord(
      id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "Server-backed append",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_520)
    )
    let responseMessage = OrbitMessageRecord(
      id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
      postID: postID,
      threadID: threadID,
      authorType: .workspacePersona,
      authorID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!.uuidString,
      replyToMessageID: updatedMessage.id,
      body: "I am on it. I am treating \"Server-backed append\" as the active objective and keeping the first checkpoint bounded to workspace, roster, conversation, and trace.",
      messageFormat: .markdown,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_521),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
    let activation = OrbitPersonaActivationRecord(
      id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
      initiatedByParticipantType: .user,
      initiatedByParticipantID: "aj",
      workspaceID: workspaceID,
      channelID: channelID,
      originPostID: postID,
      originThreadID: threadID,
      triggerMessageID: updatedMessage.id,
      addressedTargetKind: .collaborator,
      addressedTargetReferenceID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!.uuidString,
      resolvedWorkspacePersonaInstanceID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
      responseMode: .directAddress,
      createdAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
    let agentRun = OrbitAgentRunRecord(
      id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
      personaActivationID: activation.id,
      runnerKind: "local-bridge",
      status: .completed,
      startedAt: Date(timeIntervalSince1970: 1_742_342_521),
      completedAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
    let postEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activation: activation,
          agentRun: agentRun,
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
      createdAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
    let updatedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: initialSnapshot.room.workspace,
        channel: initialSnapshot.room.channel,
        workspacePersonas: initialSnapshot.room.workspacePersonas,
        post: initialSnapshot.room.post,
        thread: initialSnapshot.room.thread,
        messages: initialSnapshot.room.messages + [updatedMessage, responseMessage],
        postParticipants: initialSnapshot.room.postParticipants,
        postEvents: initialSnapshot.room.postEvents + [postEvent],
        personaActivations: initialSnapshot.room.personaActivations + [activation],
        agentRuns: initialSnapshot.room.agentRuns + [agentRun]
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: responseMessage.id,
        lastEventCreatedAt: responseMessage.createdAt
      )
    )
    let transport = StubClientTransport(
      connectResponse: .bootstrap(updatedSnapshot.replayCursorSession, updatedSnapshot),
      pollResponse: .noChange(updatedSnapshot.replayCursorSession)
    )
    let roomWriter = StubClientRoomWriter(
      result: OrbitPhase1AppendUserMessageResult(
        snapshot: initialSnapshot.room,
        message: updatedMessage
      )
    )
    let systemWriter = StubClientSystemWriter(
      result: OrbitPhase1AppendSystemMessageResult(
        snapshot: initialSnapshot.room,
        message: OrbitMessageRecord(
          id: UUID(uuidString: "f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0")!,
          postID: postID,
          threadID: threadID,
          authorType: .system,
          authorID: "orbit-system",
          body: "unused",
          messageFormat: .plainText,
          state: .completed,
          createdAt: Date(timeIntervalSince1970: 1_742_342_521),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_521)
        )
      )
    )
    let failureWriter = StubClientFailureWriter(
      result: OrbitPhase1AppendActivationFailureResult(
        snapshot: initialSnapshot.room,
        systemMessage: OrbitMessageRecord(
          id: UUID(uuidString: "f1f1f1f1-f1f1-f1f1-f1f1-f1f1f1f1f1f1")!,
          postID: postID,
          threadID: threadID,
          authorType: .system,
          authorID: "orbit-system",
          body: "unused",
          messageFormat: .plainText,
          state: .completed,
          createdAt: Date(timeIntervalSince1970: 1_742_342_521),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_521)
        ),
        postEvent: postEvent
      )
    )
    let collaboratorWriter = StubClientCollaboratorWriter(
      result: OrbitPhase1AppendCollaboratorResponseResult(
        snapshot: updatedSnapshot.room,
        message: responseMessage,
        activation: activation,
        agentRun: agentRun
      )
    )
    let client = OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: roomWriter,
      systemWriter: systemWriter,
      failureWriter: failureWriter,
      collaboratorWriter: collaboratorWriter
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: initialSnapshot,
        session: sampleSession(),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: initialSnapshot)
      )
    )

    try await coordinator.appendConversationTurn(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      authorID: "aj",
      body: "Server-backed append",
      addressedParticipantID: OrbitParticipantID.samwise.rawValue,
      resolveContract: { _ in
        OrbitResolvedActivationContract(
          directiveID: "maintain-partner-sync-and-handoffs",
          directiveSource: .participantDefault,
          kitIDs: ["trusted-partner-core"],
          authorizedSkillIDs: ["codex-cli"],
          requiredSkillIDs: ["codex-cli"],
          stopPointIDs: [],
          reviewGateIDs: ["intent:partner-sync-review"],
          memoryScopeIDs: [],
          failureReasons: []
        )
      },
      client: client
    )

    #expect(await roomWriter.requests.first?.body == "Server-backed append")
    #expect(await collaboratorWriter.requests.first?.responseMode == .directAddress)
    #expect(await collaboratorWriter.requests.first?.body.contains("Server-backed append") == true)
    #expect(await collaboratorWriter.requests.first?.contract?.reviewGateIDs == ["intent:partner-sync-review"])
    #expect(await systemWriter.requests.first?.body.contains("resolved target: kind=collaborator") == true)
    #expect(await systemWriter.requests.first?.body.contains("reasonCategory=direct_target") == true)
    #expect(await failureWriter.requests.isEmpty)
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body == responseMessage.body)
    #expect(coordinator.roomState.projectedWorkspace?.activationRecords.count == 1)
    #expect(coordinator.roomState.projectedWorkspace?.activationContractSnapshots.count == 1)
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.first(where: { $0.id == updatedMessage.id.uuidString })?.addressedParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(coordinator.roomState.session?.replayCursor.lastEventID == responseMessage.id)
  }

  @Test
  func appendConversationTurnPersistsMeetingSystemEventForFoundingGroup() async throws {
    let initialSnapshot = meetingSampleSnapshot()
    let updatedMessage = OrbitMessageRecord(
      id: UUID(uuidString: "20202020-2020-2020-2020-202020202020")!,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "Founding group, align on the next Orbit checkpoint.",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_520)
    )
    let systemMessage = OrbitMessageRecord(
      id: UUID(uuidString: "21212121-2121-2121-2121-212121212121")!,
      postID: postID,
      threadID: threadID,
      authorType: .system,
      authorID: "orbit-system",
      replyToMessageID: updatedMessage.id,
      body: """
        Orbit target expansion
        resolved target: kind=team reference=founding-group workspace=orbit status=resolved
        included participants:
        - ProdDoc | reasonCategory=team_membership | sourceTargetKind=team | sourceTargetReferenceID=founding-group | Orbit included ProdDoc through persisted team membership for Founding Group.
        - Samwise | reasonCategory=team_membership | sourceTargetKind=team | sourceTargetReferenceID=founding-group | Orbit included Samwise through persisted team membership for Founding Group.
        participant states:
        - ProdDoc | role=reviewer | state=pending
        - Samwise | role=contributor | state=pending
        exchange state: active
        """,
      messageFormat: .plainText,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_521),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
    let samwiseResponse = collaboratorResponseMessage(
      id: UUID(uuidString: "22222220-2222-2222-2222-222222222220")!,
      authorID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!.uuidString,
      replyToMessageID: updatedMessage.id,
      body: "I am in the room. I will turn \"Founding group, align on the next Orbit checkpoint.\" into the next concrete execution step and keep the Orbit lane moving without widening scope.",
      createdAt: Date(timeIntervalSince1970: 1_742_342_522)
    )
    let prodDocResponse = collaboratorResponseMessage(
      id: UUID(uuidString: "23232323-2323-2323-2323-232323232323")!,
      authorID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
      replyToMessageID: updatedMessage.id,
      body: "Product lens: \"Founding group, align on the next Orbit checkpoint.\" should make the command-center surface feel more intentional than chat while staying light enough for the first checkpoint.",
      createdAt: Date(timeIntervalSince1970: 1_742_342_523)
    )
    let exchangeStateMessage = OrbitMessageRecord(
      id: UUID(uuidString: "24242420-2424-2424-2424-242424242420")!,
      postID: postID,
      threadID: threadID,
      authorType: .system,
      authorID: "orbit-system",
      replyToMessageID: updatedMessage.id,
      body: """
        Orbit exchange state
        resolved target: kind=team reference=founding-group workspace=orbit state=completed
        participant states:
        - ProdDoc | role=reviewer | state=replied
        - Samwise | role=contributor | state=replied
        """,
      messageFormat: .plainText,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_524),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_524)
    )
    let updatedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: initialSnapshot.room.workspace,
        channel: initialSnapshot.room.channel,
        workspacePersonas: initialSnapshot.room.workspacePersonas,
        teams: initialSnapshot.room.teams,
        squads: initialSnapshot.room.squads,
        workspacePersonaMemberships: initialSnapshot.room.workspacePersonaMemberships,
        post: initialSnapshot.room.post,
        thread: initialSnapshot.room.thread,
        messages: initialSnapshot.room.messages + [updatedMessage, systemMessage, samwiseResponse, prodDocResponse, exchangeStateMessage],
        postParticipants: initialSnapshot.room.postParticipants,
        postEvents: initialSnapshot.room.postEvents,
        personaActivations: initialSnapshot.room.personaActivations,
        agentRuns: initialSnapshot.room.agentRuns
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: exchangeStateMessage.id,
        lastEventCreatedAt: exchangeStateMessage.createdAt
      )
    )
    let systemWriter = StubClientSystemWriter(
      result: OrbitPhase1AppendSystemMessageResult(
        snapshot: initialSnapshot.room,
        message: systemMessage
      )
    )
    let collaboratorWriter = StubClientCollaboratorWriter(
      result: OrbitPhase1AppendCollaboratorResponseResult(
        snapshot: updatedSnapshot.room,
        message: samwiseResponse,
        activation: collaboratorActivation(
          id: UUID(uuidString: "24242424-2424-2424-2424-242424242424")!,
          workspacePersonaID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          triggerMessageID: updatedMessage.id,
          responseMode: .currentThread,
          addressedTargetKind: .team,
          addressedTargetReferenceID: OrbitAddressTargetID.foundingGroup.rawValue
        ),
        agentRun: collaboratorRun(
          id: UUID(uuidString: "25252525-2525-2525-2525-252525252525")!,
          activationID: UUID(uuidString: "24242424-2424-2424-2424-242424242424")!,
          startedAt: Date(timeIntervalSince1970: 1_742_342_522)
        )
      )
    )
    let client = OrbitServerBackedRoomClient(
      transport: StubClientTransport(
        connectResponse: .bootstrap(updatedSnapshot.replayCursorSession, updatedSnapshot),
        pollResponse: .noChange(updatedSnapshot.replayCursorSession)
      ),
      roomWriter: StubClientRoomWriter(
        result: OrbitPhase1AppendUserMessageResult(
          snapshot: initialSnapshot.room,
          message: updatedMessage
        )
      ),
      systemWriter: systemWriter,
      failureWriter: StubClientFailureWriter(
        result: activationFailureResult(
          snapshot: initialSnapshot.room,
          systemMessageBody: "unused"
        )
      ),
      collaboratorWriter: collaboratorWriter
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: initialSnapshot,
        session: sampleSession(snapshot: initialSnapshot),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: initialSnapshot)
      )
    )

    try await coordinator.appendConversationTurn(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      authorID: "aj",
      body: "Founding group, align on the next Orbit checkpoint.",
      addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue,
      resolveContract: { participant in
        if participant.id == OrbitParticipantID.samwise.rawValue {
          return OrbitResolvedActivationContract(
            directiveID: "maintain-partner-sync-and-handoffs",
            directiveSource: .participantDefault,
            kitIDs: ["trusted-partner-core"],
            authorizedSkillIDs: ["codex-cli"],
            requiredSkillIDs: ["codex-cli"],
            stopPointIDs: [],
            reviewGateIDs: ["intent:partner-sync-review"],
            memoryScopeIDs: [],
            failureReasons: []
          )
        }

        return OrbitResolvedActivationContract(
          directiveID: "run-venture-product-planning",
          directiveSource: .participantDefault,
          kitIDs: ["venture-product-core"],
          authorizedSkillIDs: ["codex-cli"],
          requiredSkillIDs: ["codex-cli"],
          stopPointIDs: ["Pause for AJ review before execution handoff."],
          reviewGateIDs: ["intent:plan-macos-feature-delivery"],
          memoryScopeIDs: [],
          failureReasons: []
        )
      },
      client: client
    )

    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.count == 6)
    #expect(await collaboratorWriter.requests.count == 2)
    #expect(await systemWriter.requests.count == 2)
    #expect(await systemWriter.requests.first?.body.contains("resolved target: kind=team reference=founding-group") == true)
    #expect(await systemWriter.requests.first?.body.contains("reasonCategory=team_membership") == true)
    #expect(await systemWriter.requests.first?.body.contains("ProdDoc | role=reviewer | state=pending") == true)
    #expect(await systemWriter.requests.last?.body.contains("Orbit exchange state") == true)
    #expect(await systemWriter.requests.last?.body.contains("state=completed") == true)
    #expect(
      coordinator.roomState.projectedWorkspace?.activeThread?.messages.contains(where: {
        $0.kind == .systemEvent
          && $0.body.contains("resolved target: kind=team reference=founding-group")
      }) == true
    )
  }

  @Test
  func appendConversationTurnWritesActivationFailureInsteadOfSynthesizingResponse() async throws {
    let initialSnapshot = prodDocSampleSnapshot()
    let updatedMessage = OrbitMessageRecord(
      id: UUID(uuidString: "30303030-3030-3030-3030-303030303030")!,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "ProdDoc, pressure-test the checkpoint.",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_520)
    )
    let blockedSystemMessage = OrbitMessageRecord(
      id: UUID(uuidString: "31313131-3131-3131-3131-313131313131")!,
      postID: postID,
      threadID: threadID,
      authorType: .system,
      authorID: "orbit-system",
      replyToMessageID: updatedMessage.id,
      body: "Orbit blocked the activation because the collaborator has no resolved directive for this checkpoint.",
      messageFormat: .plainText,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_521),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
    let failurePostEvent = OrbitPostEventRecord(
      id: UUID(uuidString: "32323232-3232-3232-3232-323232323232")!,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activationID: nil,
          initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
          initiatedByParticipantID: "aj",
          triggerMessageID: updatedMessage.id,
          failure: OrbitPhase1ActivationFailurePayload(
            addressedTargetID: OrbitParticipantID.prodDoc.rawValue,
            participantID: OrbitParticipantID.prodDoc.rawValue,
            workspacePersonaID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
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
      createdAt: blockedSystemMessage.createdAt
    )
    let updatedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: initialSnapshot.room.workspace,
        channel: initialSnapshot.room.channel,
        workspacePersonas: initialSnapshot.room.workspacePersonas,
        post: initialSnapshot.room.post,
        thread: initialSnapshot.room.thread,
        messages: initialSnapshot.room.messages + [updatedMessage, blockedSystemMessage],
        postParticipants: initialSnapshot.room.postParticipants,
        postEvents: initialSnapshot.room.postEvents + [failurePostEvent],
        personaActivations: initialSnapshot.room.personaActivations,
        agentRuns: initialSnapshot.room.agentRuns
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: blockedSystemMessage.id,
        lastEventCreatedAt: blockedSystemMessage.createdAt
      )
    )
    let collaboratorWriter = StubClientCollaboratorWriter(
      result: collaboratorResult(
        snapshot: updatedSnapshot.room,
        message: collaboratorResponseMessage(
          id: UUID(uuidString: "33333330-3333-3333-3333-333333333330")!,
          authorID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
          replyToMessageID: updatedMessage.id,
          body: "unused",
          createdAt: Date(timeIntervalSince1970: 1_742_342_522)
        ),
        activationID: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
        workspacePersonaID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        triggerMessageID: updatedMessage.id
      )
    )
    let failureWriter = StubClientFailureWriter(
      result: OrbitPhase1AppendActivationFailureResult(
        snapshot: updatedSnapshot.room,
        systemMessage: blockedSystemMessage,
        postEvent: failurePostEvent
      )
    )
    let client = OrbitServerBackedRoomClient(
      transport: StubClientTransport(
        connectResponse: .bootstrap(updatedSnapshot.replayCursorSession, updatedSnapshot),
        pollResponse: .noChange(updatedSnapshot.replayCursorSession)
      ),
      roomWriter: StubClientRoomWriter(
        result: OrbitPhase1AppendUserMessageResult(
          snapshot: initialSnapshot.room,
          message: updatedMessage
        )
      ),
      systemWriter: StubClientSystemWriter(
        result: OrbitPhase1AppendSystemMessageResult(
          snapshot: initialSnapshot.room,
          message: blockedSystemMessage
        )
      ),
      failureWriter: failureWriter,
      collaboratorWriter: collaboratorWriter
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: initialSnapshot,
        session: sampleSession(snapshot: initialSnapshot),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: initialSnapshot)
      )
    )

    try await coordinator.appendConversationTurn(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      authorID: "aj",
      body: "ProdDoc, pressure-test the checkpoint.",
      addressedParticipantID: OrbitParticipantID.prodDoc.rawValue,
      resolveContract: { _ in
        OrbitResolvedActivationContract(
          directiveID: nil,
          directiveSource: .participantDefault,
          kitIDs: ["venture-product-core"],
          authorizedSkillIDs: ["codex-cli"],
          requiredSkillIDs: ["codex-cli"],
          stopPointIDs: ["Pause for AJ review before execution handoff."],
          reviewGateIDs: ["intent:plan-macos-feature-delivery"],
          memoryScopeIDs: [],
          failureReasons: []
        )
      },
      client: client
    )

    #expect(await collaboratorWriter.requests.isEmpty)
    #expect(await failureWriter.requests.first?.failure.failureReason == OrbitActivationFailureReason.missingDirective.rawValue)
    #expect(coordinator.roomState.projectedWorkspace?.activationFailureRecords.count == 1)
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body.contains("blocked the activation") == true)
  }

  @Test
  func appendConversationTurnReconnectsAfterPostWriteFailure() async throws {
    let initialSnapshot = sampleSnapshot()
    let updatedMessage = OrbitMessageRecord(
      id: UUID(uuidString: "40404040-4040-4040-4040-404040404040")!,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "Server-backed append",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_520)
    )
    let replayEvent = OrbitPhase1RealtimeEventEnvelope(
      id: updatedMessage.id,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: updatedMessage.createdAt,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1MessageCreatedPayload(
          messageID: updatedMessage.id,
          postID: postID,
          threadID: threadID,
          authorType: OrbitParticipantAuthorType.user.rawValue,
          authorID: "aj",
          body: updatedMessage.body,
          messageFormat: OrbitMessageFormat.plainText.rawValue,
          state: OrbitMessageState.persisted.rawValue,
          createdAt: updatedMessage.createdAt,
          updatedAt: updatedMessage.updatedAt,
          replyToMessageID: nil
        )
      )
    )
    let replayedSession = OrbitPhase1RealtimeSession(
      scope: sampleSession(snapshot: initialSnapshot).scope,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: replayEvent.id,
        lastEventCreatedAt: replayEvent.createdAt
      ),
      connectedAt: sampleSession(snapshot: initialSnapshot).connectedAt,
      lastInteractionAt: replayEvent.createdAt
    )
    let transport = StubClientTransport(
      connectResponse: .replay(replayedSession, [replayEvent]),
      pollResponse: .noChange(replayedSession)
    )
    let client = OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: StubClientRoomWriter(
        result: OrbitPhase1AppendUserMessageResult(
          snapshot: initialSnapshot.room,
          message: updatedMessage
        )
      ),
      systemWriter: StubClientSystemWriter(
        result: OrbitPhase1AppendSystemMessageResult(
          snapshot: initialSnapshot.room,
          message: collaboratorResponseMessage(
            id: UUID(uuidString: "41414141-4141-4141-4141-414141414141")!,
            authorID: "orbit-system",
            replyToMessageID: updatedMessage.id,
            body: "unused",
            createdAt: Date(timeIntervalSince1970: 1_742_342_521)
          )
        )
      ),
      failureWriter: StubClientFailureWriter(
        result: activationFailureResult(
          snapshot: initialSnapshot.room,
          systemMessageBody: "unused"
        )
      ),
      collaboratorWriter: StubClientCollaboratorWriter(
        result: collaboratorResult(
          snapshot: initialSnapshot.room,
          message: collaboratorResponseMessage(
            id: UUID(uuidString: "42424242-4242-4242-4242-424242424242")!,
            authorID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!.uuidString,
            replyToMessageID: updatedMessage.id,
            body: "unused",
            createdAt: Date(timeIntervalSince1970: 1_742_342_521)
          ),
          activationID: UUID(uuidString: "43434343-4343-4343-4343-434343434343")!,
          workspacePersonaID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          triggerMessageID: updatedMessage.id
        ),
        error: TestFailure.simulatedFailure
      )
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: initialSnapshot,
        session: sampleSession(snapshot: initialSnapshot),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: initialSnapshot)
      )
    )

    do {
      try await coordinator.appendConversationTurn(
        scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
        authorID: "aj",
        body: "Server-backed append",
        addressedParticipantID: OrbitParticipantID.samwise.rawValue,
        resolveContract: { _ in
          OrbitResolvedActivationContract(
            directiveID: "maintain-partner-sync-and-handoffs",
            directiveSource: .participantDefault,
            kitIDs: ["trusted-partner-core"],
            authorizedSkillIDs: ["codex-cli"],
            requiredSkillIDs: ["codex-cli"],
            stopPointIDs: [],
            reviewGateIDs: ["intent:partner-sync-review"],
            memoryScopeIDs: [],
            failureReasons: []
          )
        },
        client: client
      )
      Issue.record("Expected collaborator append failure")
    } catch TestFailure.simulatedFailure {
      #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body == "Server-backed append")
      #expect(coordinator.roomState.session?.replayCursor.lastEventID == updatedMessage.id)
      #expect(await transport.connectRequests.first?.cursor == initialSnapshot.replayCursor)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func sampleSession(
    snapshot: OrbitPhase1RealtimeSnapshot? = nil
  ) -> OrbitPhase1RealtimeSession {
    let snapshot = snapshot ?? sampleSnapshot()

    return OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      replayCursor: snapshot.replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
  }

  private func replaySession(
    lastEventID: UUID,
    lastEventCreatedAt: Date
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: lastEventID,
        lastEventCreatedAt: lastEventCreatedAt
      ),
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: lastEventCreatedAt
    )
  }

  private func threadActivityEvent(
    id: UUID,
    createdAt: Date,
    lastActivityAt: Date
  ) -> OrbitPhase1RealtimeEventEnvelope {
    OrbitPhase1RealtimeEventEnvelope(
      id: id,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .threadActivityUpdated,
      createdAt: createdAt,
      payloadJSON: try! OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ThreadActivityUpdatedPayload(
          threadID: threadID,
          lastActivityAt: lastActivityAt
        )
      )
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
          id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
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
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Orbit room bootstrapped.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        )
      ]
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
      )
    )
  }

  private func prodDocSampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let room = OrbitPhase1RoomSnapshot(
      workspace: sampleSnapshot().room.workspace,
      channel: sampleSnapshot().room.channel,
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          workspaceID: workspaceID,
          personaTemplateID: "venture-product-steward",
          displayName: "ProdDoc",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        )
      ],
      post: sampleSnapshot().room.post,
      thread: sampleSnapshot().room.thread,
      messages: sampleSnapshot().room.messages,
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "98989898-9898-9898-9898-989898989898")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-proddoc",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        )
      ]
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: sampleSnapshot().replayCursor
    )
  }

  private func meetingSampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let foundingGroupTeamID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    let room = OrbitPhase1RoomSnapshot(
      workspace: sampleSnapshot().room.workspace,
      channel: sampleSnapshot().room.channel,
      workspacePersonas: [
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          workspaceID: workspaceID,
          personaTemplateID: "samwise",
          displayName: "Samwise",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        ),
        OrbitWorkspacePersonaRecord(
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          workspaceID: workspaceID,
          personaTemplateID: "venture-product-steward",
          displayName: "ProdDoc",
          status: .active,
          createdAt: Date(timeIntervalSince1970: 1_742_342_401)
        )
      ],
      teams: [
        OrbitTeamRecord(
          id: foundingGroupTeamID,
          workspaceID: workspaceID,
          slug: OrbitAddressTargetID.foundingGroup.rawValue,
          name: OrbitAddressTargetID.foundingGroup.displayText,
          purpose: "Seeded first team target.",
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        )
      ],
      workspacePersonaMemberships: [
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "12121212-3434-5656-7878-909090909090")!,
          workspacePersonaID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          teamID: foundingGroupTeamID,
          roleInGroup: "trusted-partner",
          createdAt: Date(timeIntervalSince1970: 1_742_342_402)
        ),
        OrbitWorkspacePersonaMembershipRecord(
          id: UUID(uuidString: "23232323-4545-6767-8989-010101010101")!,
          workspacePersonaID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          teamID: foundingGroupTeamID,
          roleInGroup: "product-steward",
          createdAt: Date(timeIntervalSince1970: 1_742_342_403)
        ),
      ],
      post: sampleSnapshot().room.post,
      thread: sampleSnapshot().room.thread,
      messages: sampleSnapshot().room.messages,
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        ),
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "89898989-8989-8989-8989-898989898989")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-proddoc",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_406),
          participationMode: .active
        )
      ]
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: sampleSnapshot().replayCursor
    )
  }

  private func collaboratorResponseMessage(
    id: UUID,
    authorID: String,
    replyToMessageID: UUID,
    body: String,
    createdAt: Date
  ) -> OrbitMessageRecord {
    OrbitMessageRecord(
      id: id,
      postID: postID,
      threadID: threadID,
      authorType: .workspacePersona,
      authorID: authorID,
      replyToMessageID: replyToMessageID,
      body: body,
      messageFormat: .markdown,
      state: .completed,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  private func collaboratorActivation(
    id: UUID,
    workspacePersonaID: UUID,
    triggerMessageID: UUID,
    responseMode: OrbitCanonicalResponseMode = .directAddress,
    addressedTargetKind: OrbitAddressedTargetKind? = nil,
    addressedTargetReferenceID: String? = nil
  ) -> OrbitPersonaActivationRecord {
    let resolvedTargetKind = addressedTargetKind ?? (responseMode == .directAddress ? .collaborator : .team)
    let resolvedTargetReferenceID =
      addressedTargetReferenceID
      ?? (resolvedTargetKind == .collaborator
        ? workspacePersonaID.uuidString
        : OrbitAddressTargetID.foundingGroup.rawValue)

    return OrbitPersonaActivationRecord(
      id: id,
      initiatedByParticipantType: .user,
      initiatedByParticipantID: "aj",
      workspaceID: workspaceID,
      channelID: channelID,
      originPostID: postID,
      originThreadID: threadID,
      triggerMessageID: triggerMessageID,
      addressedTargetKind: resolvedTargetKind,
      addressedTargetReferenceID: resolvedTargetReferenceID,
      resolvedWorkspacePersonaInstanceID: workspacePersonaID,
      responseMode: responseMode,
      createdAt: Date(timeIntervalSince1970: 1_742_342_521)
    )
  }

  private func collaboratorRun(
    id: UUID,
    activationID: UUID,
    startedAt: Date
  ) -> OrbitAgentRunRecord {
    OrbitAgentRunRecord(
      id: id,
      personaActivationID: activationID,
      runnerKind: "local-bridge",
      status: .completed,
      startedAt: startedAt,
      completedAt: startedAt
    )
  }

  private func collaboratorResult(
    snapshot: OrbitPhase1RoomSnapshot,
    message: OrbitMessageRecord,
    activationID: UUID,
    workspacePersonaID: UUID,
    triggerMessageID: UUID
  ) -> OrbitPhase1AppendCollaboratorResponseResult {
    let activation = collaboratorActivation(
      id: activationID,
      workspacePersonaID: workspacePersonaID,
      triggerMessageID: triggerMessageID
    )
    let agentRun = collaboratorRun(
      id: UUID(uuidString: "91919191-9191-9191-9191-919191919191")!,
      activationID: activationID,
      startedAt: message.createdAt
    )

    return OrbitPhase1AppendCollaboratorResponseResult(
      snapshot: snapshot,
      message: message,
      activation: activation,
      agentRun: agentRun
    )
  }

  private func activationFailureResult(
    snapshot: OrbitPhase1RoomSnapshot,
    systemMessageBody: String
  ) -> OrbitPhase1AppendActivationFailureResult {
    OrbitPhase1AppendActivationFailureResult(
      snapshot: snapshot,
      systemMessage: OrbitMessageRecord(
        id: UUID(uuidString: "92929292-9292-9292-9292-929292929292")!,
        postID: postID,
        threadID: threadID,
        authorType: .system,
        authorID: "orbit-system",
        body: systemMessageBody,
        messageFormat: .plainText,
        state: .completed,
        createdAt: Date(timeIntervalSince1970: 1_742_342_521),
        updatedAt: Date(timeIntervalSince1970: 1_742_342_521)
      ),
      postEvent: OrbitPostEventRecord(
        id: UUID(uuidString: "93939393-9393-9393-9393-939393939393")!,
        postID: postID,
        threadID: threadID,
        eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
        payloadJSON: "{}",
        createdAt: Date(timeIntervalSince1970: 1_742_342_521)
      )
    )
  }
}

private struct StubTransport: OrbitPhase1RealtimeTransportServing {
  let connectResponse: OrbitPhase1RealtimeTransportResponse
  let pollResponse: OrbitPhase1RealtimeTransportResponse

  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    connectResponse
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    pollResponse
  }
}

private actor StubClientTransport: OrbitPhase1RealtimeTransportServing {
  let connectResponse: OrbitPhase1RealtimeTransportResponse
  let pollResponse: OrbitPhase1RealtimeTransportResponse
  var connectRequests = [OrbitPhase1RealtimeConnectRequest]()

  init(
    connectResponse: OrbitPhase1RealtimeTransportResponse,
    pollResponse: OrbitPhase1RealtimeTransportResponse
  ) {
    self.connectResponse = connectResponse
    self.pollResponse = pollResponse
  }

  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    connectRequests.append(request)
    return connectResponse
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    return pollResponse
  }
}

private actor SequencedClientTransport: OrbitPhase1RealtimeTransportServing {
  private var remainingConnectResponses: [OrbitPhase1RealtimeTransportResponse]
  let pollResponse: OrbitPhase1RealtimeTransportResponse
  var connectRequests = [OrbitPhase1RealtimeConnectRequest]()

  init(
    connectResponses: [OrbitPhase1RealtimeTransportResponse],
    pollResponse: OrbitPhase1RealtimeTransportResponse
  ) {
    self.remainingConnectResponses = connectResponses
    self.pollResponse = pollResponse
  }

  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    connectRequests.append(request)

    guard !remainingConnectResponses.isEmpty else {
      throw TestFailure.simulatedFailure
    }

    return remainingConnectResponses.removeFirst()
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    return pollResponse
  }
}

private actor StubClientRoomWriter: OrbitPhase1RoomWriteServing {
  let result: OrbitPhase1AppendUserMessageResult
  var requests = [OrbitPhase1AppendUserMessageRequest]()

  init(
    result: OrbitPhase1AppendUserMessageResult
  ) {
    self.result = result
  }

  func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult {
    requests.append(request)
    return result
  }
}

private actor StubClientCollaboratorWriter: OrbitPhase1CollaboratorResponseServing {
  let result: OrbitPhase1AppendCollaboratorResponseResult
  let error: Error?
  var requests = [OrbitPhase1AppendCollaboratorResponseRequest]()

  init(
    result: OrbitPhase1AppendCollaboratorResponseResult,
    error: Error? = nil
  ) {
    self.result = result
    self.error = error
  }

  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    requests.append(request)

    if let error {
      throw error
    }

    return result
  }
}

private actor StubClientSystemWriter: OrbitPhase1SystemMessageServing {
  let result: OrbitPhase1AppendSystemMessageResult
  var requests = [OrbitPhase1AppendSystemMessageRequest]()

  init(
    result: OrbitPhase1AppendSystemMessageResult
  ) {
    self.result = result
  }

  func appendSystemMessage(
    _ request: OrbitPhase1AppendSystemMessageRequest
  ) async throws -> OrbitPhase1AppendSystemMessageResult {
    requests.append(request)
    return result
  }
}

private actor StubClientFailureWriter: OrbitPhase1ActivationFailureServing {
  let result: OrbitPhase1AppendActivationFailureResult
  var requests = [OrbitPhase1AppendActivationFailureRequest]()

  init(
    result: OrbitPhase1AppendActivationFailureResult
  ) {
    self.result = result
  }

  func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult {
    requests.append(request)
    return result
  }
}

private extension OrbitPhase1RealtimeSnapshot {
  var replayCursorSession: OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: room.workspace.slug, channelSlug: room.channel.slug),
      replayCursor: replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
  }
}
