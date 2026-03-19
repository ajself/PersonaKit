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
    let transport = StubClientTransport(
      connectResponse: .bootstrap(snapshot.replayCursorSession, snapshot),
      pollResponse: .noChange(snapshot.replayCursorSession)
    )
    let roomWriter = StubClientRoomWriter(result: appendResult)
    let client = OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: roomWriter
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

    #expect(connectResponse == .bootstrap(snapshot.replayCursorSession, snapshot))
    #expect(pollResponse == .noChange(snapshot.replayCursorSession))
    #expect(appendResponse == appendResult)
    #expect(await transport.connectCalls == [scope])
    #expect(await transport.pollCalls.count == 1)
    #expect(await roomWriter.requests.first?.body == "server-backed")
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
  var connectCalls = [OrbitPhase1RealtimeSubscriptionScope]()
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
    connectCalls.append(request.scope)
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
