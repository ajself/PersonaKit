import Foundation
import Testing
import Vapor
import XCTVapor

@testable import OrbitServerGateway
@testable import OrbitServerRuntime

struct OrbitServerGatewayTests {
  @Test
  func connectRouteReturnsBootstrapPayload() throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let app = Application(.testing)
    defer { app.shutdown() }

    OrbitGatewayRoutes.register(
      on: app,
      transport: StubTransport(
        connectHandler: { _ in
          .bootstrap(
            OrbitPhase1RealtimeSession(
              scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
              replayCursor: snapshot.replayCursor,
              connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
              lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
            ),
            snapshot
          )
        },
        pollHandler: { _ in
          Issue.record("Poll should not be called")
          return .noChange(snapshot.replayCursorSession)
        }
      )
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "/api/orbit/realtime/connect", beforeRequest: { request in
        try request.content.encode(
          OrbitGatewayConnectRequest(
            workspaceSlug: "orbit",
            channelSlug: "command-center"
          )
        )
      }, afterResponse: { response in
        #expect(response.status == .ok)
        let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
        #expect(payload.kind == "bootstrap")
        #expect(payload.snapshot?.workspaceSlug == "orbit")
        #expect(payload.snapshot?.messageCount == 0)
      })
    }
  }

  @Test
  func appendMessageRouteReturnsCanonicalWritePayload() throws {
    let app = Application(.testing)
    defer { app.shutdown() }

    OrbitGatewayRoutes.register(
      on: app,
      transport: StubTransport(
        connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
        pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
      ),
      roomWriter: StubRoomWriter { request in
        #expect(request.workspaceSlug == "orbit")
        #expect(request.channelSlug == "command-center")
        #expect(request.authorID == "aj")
        #expect(request.body == "Canonical write path")

        let snapshot = sampleSnapshot(cursorEventID: UUID())
        let message = OrbitMessageRecord(
          id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
          postID: snapshot.room.post.id,
          threadID: snapshot.room.thread.id,
          authorType: .user,
          authorID: request.authorID,
          body: request.body,
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
        )
        let updatedSnapshot = OrbitPhase1RoomSnapshot(
          workspace: snapshot.room.workspace,
          channel: snapshot.room.channel,
          post: snapshot.room.post,
          thread: snapshot.room.thread,
          messages: snapshot.room.messages + [message]
        )

        return OrbitPhase1AppendUserMessageResult(
          snapshot: updatedSnapshot,
          message: message
        )
      }
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "/api/orbit/room/messages", beforeRequest: { request in
        try request.content.encode(
          OrbitGatewayAppendMessageRequest(
            workspaceSlug: "orbit",
            channelSlug: "command-center",
            authorID: "aj",
            body: "Canonical write path"
          )
        )
      }, afterResponse: { response in
        #expect(response.status == .ok)
        let payload = try response.content.decode(OrbitGatewayAppendMessageResponse.self)
        #expect(payload.workspaceSlug == "orbit")
        #expect(payload.channelSlug == "command-center")
        #expect(payload.messageCount == 1)
      })
    }
  }

  @Test
  func appendCollaboratorResponseRouteReturnsCanonicalResponsePayload() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    let activationID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let agentRunID = UUID(uuidString: "13131313-1313-1313-1313-131313131313")!

    OrbitGatewayRoutes.register(
      on: app,
      transport: StubTransport(
        connectHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) },
        pollHandler: { _ in .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession) }
      ),
      collaboratorWriter: StubCollaboratorWriter { request in
        #expect(request.workspaceSlug == "orbit")
        #expect(request.channelSlug == "command-center")
        #expect(request.body == "Canonical collaborator response")

        let snapshot = sampleSnapshot(cursorEventID: UUID())
        let message = OrbitMessageRecord(
          id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
          postID: snapshot.room.post.id,
          threadID: snapshot.room.thread.id,
          authorType: .workspacePersona,
          authorID: request.workspacePersonaID.uuidString,
          replyToMessageID: request.triggerMessageID,
          body: request.body,
          messageFormat: .markdown,
          state: .completed,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
        )
        let activation = OrbitPersonaActivationRecord(
          id: activationID,
          initiatedByParticipantType: .user,
          initiatedByParticipantID: request.initiatedByParticipantID,
          workspaceID: snapshot.room.workspace.id,
          channelID: snapshot.room.channel.id,
          originPostID: snapshot.room.post.id,
          originThreadID: snapshot.room.thread.id,
          triggerMessageID: request.triggerMessageID,
          addressedTargetKind: request.addressedTargetKind,
          addressedTargetReferenceID: request.addressedTargetReferenceID,
          resolvedWorkspacePersonaInstanceID: request.workspacePersonaID,
          responseMode: request.responseMode,
          createdAt: Date(timeIntervalSince1970: 1_742_342_500)
        )
        let agentRun = OrbitAgentRunRecord(
          id: agentRunID,
          personaActivationID: activation.id,
          runnerKind: request.runnerKind,
          status: .completed,
          startedAt: Date(timeIntervalSince1970: 1_742_342_500),
          completedAt: Date(timeIntervalSince1970: 1_742_342_500)
        )

        return OrbitPhase1AppendCollaboratorResponseResult(
          snapshot: snapshot.room,
          message: message,
          activation: activation,
          agentRun: agentRun
        )
      }
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "/api/orbit/room/responses", beforeRequest: { request in
        try request.content.encode(
          OrbitGatewayAppendCollaboratorResponseRequest(
            workspaceSlug: "orbit",
            channelSlug: "command-center",
            workspacePersonaID: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
            initiatedByParticipantID: "aj",
            triggerMessageID: UUID(uuidString: "16161616-1616-1616-1616-161616161616")!,
            addressedTargetKind: OrbitAddressedTargetKind.collaborator.rawValue,
            addressedTargetReferenceID: "workspace-persona-orbit-samwise",
            responseMode: OrbitCanonicalResponseMode.directAddress.rawValue,
            body: "Canonical collaborator response"
          )
        )
      }, afterResponse: { response in
        #expect(response.status == .ok)
        let payload = try response.content.decode(OrbitGatewayAppendCollaboratorResponse.self)
        #expect(payload.activationID == activationID)
        #expect(payload.agentRunID == agentRunID)
      })
    }
  }

  @Test
  func pollRouteReturnsReplayPayload() throws {
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
      workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      payloadJSON: "{}"
    )
    let app = Application(.testing)
    defer { app.shutdown() }

    OrbitGatewayRoutes.register(
      on: app,
      transport: StubTransport(
        connectHandler: { _ in
          Issue.record("Connect should not be called")
          return .noChange(sampleSnapshot(cursorEventID: UUID()).replayCursorSession)
        },
        pollHandler: { request in
          .replay(request.session.updatedSession(with: event), [event])
        }
      )
    )

    let session = OrbitGatewaySessionPayload(
      workspaceSlug: "orbit",
      channelSlug: "command-center",
      workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      cursorEventID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
      cursorEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_400),
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_410)
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "/api/orbit/realtime/poll", beforeRequest: { request in
        try request.content.encode(OrbitGatewayPollRequest(session: session))
      }, afterResponse: { response in
        #expect(response.status == .ok)
        let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
        #expect(payload.kind == "replay")
        #expect(payload.events.count == 1)
        #expect(payload.events.first?.category == "message.created")
        #expect(payload.session.cursorEventID == event.id)
      })
    }
  }

  @Test
  func pollRouteReturnsResyncPayload() throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!)
    let app = Application(.testing)
    defer { app.shutdown() }

    OrbitGatewayRoutes.register(
      on: app,
      transport: StubTransport(
        connectHandler: { _ in
          Issue.record("Connect should not be called")
          return .noChange(snapshot.replayCursorSession)
        },
        pollHandler: { request in
          .resync(request.session.updatedSession(with: snapshot.replayCursor), snapshot, .staleClient)
        }
      )
    )

    let session = OrbitGatewaySessionPayload(
      workspaceSlug: "orbit",
      channelSlug: "command-center",
      workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      cursorEventID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
      cursorEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_400),
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_410)
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "/api/orbit/realtime/poll", beforeRequest: { request in
        try request.content.encode(OrbitGatewayPollRequest(session: session))
      }, afterResponse: { response in
        #expect(response.status == .ok)
        let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
        #expect(payload.kind == "resync")
        #expect(payload.resyncReason == "stale-client")
        #expect(payload.snapshot?.workspaceSlug == "orbit")
      })
    }
  }
}

private struct StubTransport: OrbitRealtimeTransportHandling {
  let connectHandler: @Sendable (OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse
  let pollHandler: @Sendable (OrbitPhase1RealtimePollRequest) async throws -> OrbitPhase1RealtimeTransportResponse

  func connect(request: OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await connectHandler(request)
  }

  func poll(request: OrbitPhase1RealtimePollRequest) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await pollHandler(request)
  }
}

private struct StubRoomWriter: OrbitPhase1RoomWriteServing {
  let appendHandler: @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult

  init(
    _ appendHandler: @escaping @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult {
    try await appendHandler(request)
  }
}

private struct StubCollaboratorWriter: OrbitCollaboratorResponseHandling {
  let appendHandler: @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult

  init(
    _ appendHandler: @escaping @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult
  ) {
    self.appendHandler = appendHandler
  }

  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    try await appendHandler(request)
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

private extension OrbitPhase1RealtimeSession {
  func updatedSession(
    with event: OrbitPhase1RealtimeEventEnvelope
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: scope,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: replayCursor.workspaceID,
        lastEventID: event.id,
        lastEventCreatedAt: event.createdAt
      ),
      connectedAt: connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_420)
    )
  }

  func updatedSession(
    with cursor: OrbitPhase1ReplayCursor
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: scope,
      replayCursor: cursor,
      connectedAt: connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_500)
    )
  }
}

private func sampleSnapshot(
  cursorEventID: UUID
) -> OrbitPhase1RealtimeSnapshot {
  let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  let room = OrbitPhase1RoomSnapshot(
    workspace: OrbitWorkspaceRecord(
      id: workspaceID,
      slug: "orbit",
      name: "Orbit",
      status: .active,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400)
    ),
    channel: OrbitChannelRecord(
      id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      workspaceID: workspaceID,
      slug: "command-center",
      name: "Command Center",
      purpose: "Primary Orbit room",
      status: .active,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400)
    ),
    post: OrbitPostRecord(
      id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
      workspaceID: workspaceID,
      channelID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      postType: .message,
      createdByParticipantType: .user,
      createdByParticipantID: "aj",
      title: "Orbit room",
      status: .active,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400)
    ),
    thread: OrbitThreadRecord(
      id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
      postID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
      status: .open,
      lastActivityAt: Date(timeIntervalSince1970: 1_742_342_460),
      createdAt: Date(timeIntervalSince1970: 1_742_342_400)
    ),
    messages: []
  )

  return OrbitPhase1RealtimeSnapshot(
    room: room,
    replayCursor: OrbitPhase1ReplayCursor(
      workspaceID: workspaceID,
      lastEventID: cursorEventID,
      lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
    )
  )
}
