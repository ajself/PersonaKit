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
  func appendUserMessageRefreshesProjectedWorkspaceFromServerClient() async throws {
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
    let updatedSnapshot = OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: initialSnapshot.room.workspace,
        channel: initialSnapshot.room.channel,
        workspacePersonas: initialSnapshot.room.workspacePersonas,
        post: initialSnapshot.room.post,
        thread: initialSnapshot.room.thread,
        messages: initialSnapshot.room.messages + [updatedMessage],
        postParticipants: initialSnapshot.room.postParticipants,
        postEvents: initialSnapshot.room.postEvents,
        personaActivations: initialSnapshot.room.personaActivations,
        agentRuns: initialSnapshot.room.agentRuns
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: updatedMessage.id,
        lastEventCreatedAt: updatedMessage.createdAt
      )
    )
    let transport = StubClientTransport(
      connectResponse: .bootstrap(updatedSnapshot.replayCursorSession, updatedSnapshot),
      pollResponse: .noChange(updatedSnapshot.replayCursorSession)
    )
    let roomWriter = StubClientRoomWriter(
      result: OrbitPhase1AppendUserMessageResult(
        snapshot: updatedSnapshot.room,
        message: updatedMessage
      )
    )
    let client = OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: roomWriter
    )
    var coordinator = OrbitServerBackedRoomCoordinator(
      roomState: OrbitServerBackedRoomState(
        snapshot: initialSnapshot,
        session: sampleSession(),
        projectedWorkspace: OrbitServerRoomProjection.workspace(from: initialSnapshot)
      )
    )

    try await coordinator.appendUserMessage(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      authorID: "aj",
      body: "Server-backed append",
      client: client
    )

    #expect(await roomWriter.requests.first?.body == "Server-backed append")
    #expect(coordinator.roomState.projectedWorkspace?.activeThread?.messages.last?.body == "Server-backed append")
    #expect(coordinator.roomState.session?.replayCursor.lastEventID == updatedMessage.id)
  }

  private func sampleSession() -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      replayCursor: sampleSnapshot().replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
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
    connectResponse
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    pollResponse
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
