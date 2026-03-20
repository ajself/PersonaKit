import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitServerBackedRoomClientTests {
  @Test
  func clientDelegatesConnectPollAndAppendToUnderlyingServices() async throws {
    let snapshot = sampleSnapshot()
    let appendResult = OrbitPhase1AppendUserMessageResult(
      snapshot: snapshot.room,
      message: OrbitMessageRecord(
        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        postID: snapshot.room.post.id,
        threadID: snapshot.room.thread.id,
        authorType: .user,
        authorID: "aj",
        body: "server-backed",
        messageFormat: .plainText,
        state: .persisted,
        createdAt: Date(timeIntervalSince1970: 1_742_342_500),
        updatedAt: Date(timeIntervalSince1970: 1_742_342_500)
      )
    )
    let collaboratorResult = OrbitPhase1AppendCollaboratorResponseResult(
      snapshot: snapshot.room,
      message: OrbitMessageRecord(
        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        postID: snapshot.room.post.id,
        threadID: snapshot.room.thread.id,
        authorType: .workspacePersona,
        authorID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
        replyToMessageID: appendResult.message.id,
        body: "Canonical collaborator response",
        messageFormat: .markdown,
        state: .completed,
        createdAt: Date(timeIntervalSince1970: 1_742_342_510),
        updatedAt: Date(timeIntervalSince1970: 1_742_342_510)
      ),
      activation: OrbitPersonaActivationRecord(
        id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
        initiatedByParticipantType: .user,
        initiatedByParticipantID: "aj",
        workspaceID: snapshot.room.workspace.id,
        channelID: snapshot.room.channel.id,
        originPostID: snapshot.room.post.id,
        originThreadID: snapshot.room.thread.id,
        triggerMessageID: appendResult.message.id,
        addressedTargetKind: .collaborator,
        addressedTargetReferenceID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
        resolvedWorkspacePersonaInstanceID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        responseMode: .directAddress,
        createdAt: Date(timeIntervalSince1970: 1_742_342_510)
      ),
      agentRun: OrbitAgentRunRecord(
        id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        personaActivationID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
        runnerKind: "local-bridge",
        status: .completed,
        startedAt: Date(timeIntervalSince1970: 1_742_342_510),
        completedAt: Date(timeIntervalSince1970: 1_742_342_510)
      )
    )
    let systemResult = OrbitPhase1AppendSystemMessageResult(
      snapshot: snapshot.room,
      message: OrbitMessageRecord(
        id: UUID(uuidString: "10101010-1010-1010-1010-101010101010")!,
        postID: snapshot.room.post.id,
        threadID: snapshot.room.thread.id,
        authorType: .system,
        authorID: "orbit-system",
        body: "Meeting system event",
        messageFormat: .plainText,
        state: .completed,
        createdAt: Date(timeIntervalSince1970: 1_742_342_511),
        updatedAt: Date(timeIntervalSince1970: 1_742_342_511)
      )
    )
    let failureResult = OrbitPhase1AppendActivationFailureResult(
      snapshot: snapshot.room,
      systemMessage: OrbitMessageRecord(
        id: UUID(uuidString: "11111110-1111-1111-1111-111111111110")!,
        postID: snapshot.room.post.id,
        threadID: snapshot.room.thread.id,
        authorType: .system,
        authorID: "orbit-system",
        replyToMessageID: appendResult.message.id,
        body: "Blocked system event",
        messageFormat: .plainText,
        state: .completed,
        createdAt: Date(timeIntervalSince1970: 1_742_342_512),
        updatedAt: Date(timeIntervalSince1970: 1_742_342_512)
      ),
      postEvent: OrbitPostEventRecord(
        id: UUID(uuidString: "12121210-1212-1212-1212-121212121210")!,
        postID: snapshot.room.post.id,
        threadID: snapshot.room.thread.id,
        eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
        payloadJSON: "{}",
        createdAt: Date(timeIntervalSince1970: 1_742_342_512)
      )
    )
    let transport = StubClientTransport(
      connectResponse: .bootstrap(snapshot.replayCursorSession, snapshot),
      pollResponse: .noChange(snapshot.replayCursorSession)
    )
    let roomWriter = StubClientRoomWriter(result: appendResult)
    let systemWriter = StubClientSystemWriter(result: systemResult)
    let failureWriter = StubClientFailureWriter(result: failureResult)
    let collaboratorWriter = StubClientCollaboratorWriter(result: collaboratorResult)
    let client = OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: roomWriter,
      systemWriter: systemWriter,
      failureWriter: failureWriter,
      collaboratorWriter: collaboratorWriter
    )
    let scope = OrbitPhase1RealtimeSubscriptionScope(
      workspaceSlug: "orbit",
      channelSlug: "command-center"
    )

    let connectResponse = try await client.connect(scope: scope)
    let pollResponse = try await client.poll(session: snapshot.replayCursorSession)
    let appendResponse = try await client.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        authorID: "aj",
        body: "server-backed"
      )
    )
    let collaboratorResponse = try await client.appendCollaboratorResponse(
      OrbitPhase1AppendCollaboratorResponseRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        workspacePersonaID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        initiatedByParticipantID: "aj",
        triggerMessageID: appendResult.message.id,
        addressedTargetKind: .collaborator,
        addressedTargetReferenceID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
        responseMode: .directAddress,
        body: "Canonical collaborator response"
      )
    )
    let systemResponse = try await client.appendSystemMessage(
      OrbitPhase1AppendSystemMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        body: "Meeting system event"
      )
    )
    let failureResponse = try await client.appendActivationFailure(
      OrbitPhase1AppendActivationFailureRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        initiatedByParticipantID: "aj",
        triggerMessageID: appendResult.message.id,
        failure: OrbitPhase1ActivationFailurePayload(
          addressedTargetID: "samwise",
          participantID: "samwise",
          workspacePersonaID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!.uuidString,
          personaTemplateID: "samwise",
          directiveID: "maintain-partner-sync-and-handoffs",
          triggerSource: "directAddress",
          systemEventMessageID: UUID(uuidString: "11111110-1111-1111-1111-111111111110")!,
          requiredSkillIDs: ["codex-cli"],
          authorizedSkillIDs: [],
          failureReason: "unauthorizedSkillPosture",
          systemEventBody: "Blocked system event"
        )
      )
    )

    #expect(connectResponse == .bootstrap(snapshot.replayCursorSession, snapshot))
    #expect(pollResponse == .noChange(snapshot.replayCursorSession))
    #expect(appendResponse == appendResult)
    #expect(collaboratorResponse == collaboratorResult)
    #expect(systemResponse == systemResult)
    #expect(failureResponse == failureResult)
    #expect(
      await transport.connectCalls == [
        OrbitPhase1RealtimeConnectRequest(
          scope: scope,
          cursor: nil
        )
      ]
    )
    #expect(await transport.pollCalls.count == 1)
    #expect(await roomWriter.requests.first?.body == "server-backed")
    #expect(await systemWriter.requests.first?.body == "Meeting system event")
    #expect(await failureWriter.requests.first?.failure.failureReason == "unauthorizedSkillPosture")
    #expect(await collaboratorWriter.requests.first?.body == "Canonical collaborator response")
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
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
      messages: []
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

private actor StubClientTransport: OrbitPhase1RealtimeTransportServing {
  let connectResponse: OrbitPhase1RealtimeTransportResponse
  let pollResponse: OrbitPhase1RealtimeTransportResponse
  var connectCalls = [OrbitPhase1RealtimeConnectRequest]()
  var pollCalls = [OrbitPhase1RealtimeSession]()

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
    connectCalls.append(request)
    return connectResponse
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    pollCalls.append(request.session)
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
  var requests = [OrbitPhase1AppendCollaboratorResponseRequest]()

  init(
    result: OrbitPhase1AppendCollaboratorResponseResult
  ) {
    self.result = result
  }

  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    requests.append(request)
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
