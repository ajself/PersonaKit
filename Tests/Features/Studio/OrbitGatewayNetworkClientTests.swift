import Foundation
import Testing

@testable import OrbitServerGateway
@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitGatewayNetworkClientTests {
  @Test
  func connectDecodesBootstrapTransportFromGateway() async throws {
    let snapshot = sampleSnapshot()
    let session = sampleSession(snapshot: snapshot)
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/realtime/connect")
      let body = try JSONDecoder().decode(
        OrbitGatewayConnectRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.workspaceSlug == "orbit")
      #expect(body.channelSlug == "command-center")

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayTransportResponse(
          response: .bootstrap(session, snapshot)
        ),
        url: try #require(request.url)
      )
    }

    let response = try await client.connect(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center"
        )
      )
    )

    #expect(response == .bootstrap(session, snapshot))
  }

  @Test
  func persistentTransportResponsesSendBootstrapThenPollOverTheSameSocket() async throws {
    let snapshot = sampleSnapshot()
    let bootstrapSession = sampleSession(snapshot: snapshot)
    let handshakeURL = CapturedURLBox()
    let polledSession = OrbitPhase1RealtimeSession(
      scope: bootstrapSession.scope,
      replayCursor: bootstrapSession.replayCursor,
      connectedAt: bootstrapSession.connectedAt,
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_430)
    )
    let socket = StubSocket(
      receivedTexts: [
        try makeSocketPayload(
          OrbitGatewayTransportResponse(
            response: .bootstrap(bootstrapSession, snapshot)
          )
        ),
        try makeSocketPayload(
          OrbitGatewayTransportResponse(
            response: .noChange(polledSession)
          )
        ),
      ]
    )
    let sleep = StubSleep(maxSleepsBeforeCancellation: 1)
    let client = OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://orbit.example")!,
      session: URLSession(configuration: .ephemeral),
      socketFactory: { _, url in
        handshakeURL.set(url)
        return socket
      },
      sleep: { duration in
        try await sleep.pause(for: duration)
      }
    )

    let responses = try await client.persistentTransportResponses(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center"
        )
      ),
      pollInterval: Duration.seconds(2)
    )
    var iterator = responses.makeAsyncIterator()
    let bootstrapResponse = try await iterator.next()
    let pollResponse = try await iterator.next()

    #expect(bootstrapResponse == .bootstrap(bootstrapSession, snapshot))
    #expect(pollResponse == .noChange(polledSession))

    let sentMessages = await socket.sentTexts
    let bootstrapMessage = try JSONDecoder().decode(
      OrbitGatewayWebSocketClientMessage.self,
      from: Data(try #require(sentMessages.first).utf8)
    )
    let pollMessage = try JSONDecoder().decode(
      OrbitGatewayWebSocketClientMessage.self,
      from: Data(try #require(sentMessages.last).utf8)
    )

    #expect(bootstrapMessage.kind == .bootstrap)
    #expect(bootstrapMessage.session == nil)
    #expect(pollMessage.kind == .poll)
    #expect(pollMessage.session?.workspaceSlug == "orbit")
    #expect(pollMessage.session?.cursorEventID == snapshot.replayCursor.lastEventID)
    #expect(await socket.cancelCallCount == 1)
    let queryItems = URLComponents(
      url: try #require(handshakeURL.current),
      resolvingAgainstBaseURL: false
    )?.queryItems
    #expect(queryItems?.contains(URLQueryItem(name: "workspaceSlug", value: "orbit")) == true)
    #expect(queryItems?.contains(URLQueryItem(name: "channelSlug", value: "command-center")) == true)
  }

  @Test
  func persistentTransportResponsesEncodesReplayCursorTimestampAsEpochSeconds() async throws {
    let snapshot = sampleSnapshot()
    let handshakeURL = CapturedURLBox()
    let socket = StubSocket(
      receivedTexts: [
        try makeSocketPayload(
          OrbitGatewayTransportResponse(
            response: .bootstrap(sampleSession(snapshot: snapshot), snapshot)
          )
        ),
      ]
    )
    let sleep = StubSleep(maxSleepsBeforeCancellation: 0)
    let cursorDate = Date(timeIntervalSince1970: 1_742_342_460)
    let client = OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://orbit.example")!,
      session: URLSession(configuration: .ephemeral),
      socketFactory: { _, url in
        handshakeURL.set(url)
        return socket
      },
      sleep: { duration in
        try await sleep.pause(for: duration)
      }
    )

    let responses = try await client.persistentTransportResponses(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center"
        ),
        cursor: OrbitPhase1ReplayCursor(
          workspaceID: snapshot.replayCursor.workspaceID,
          lastEventID: snapshot.replayCursor.lastEventID,
          lastEventCreatedAt: cursorDate
        )
      )
    )
    var iterator = responses.makeAsyncIterator()

    _ = try await iterator.next()

    let handshakeURLValue = try #require(handshakeURL.current)
    let queryItems = try #require(
      URLComponents(
        url: handshakeURLValue,
        resolvingAgainstBaseURL: false
      )?.queryItems
    )
    #expect(
      queryItems.contains(
        URLQueryItem(
          name: "cursorEventCreatedAt",
          value: String(cursorDate.timeIntervalSince1970)
        )
      )
    )
  }

  @Test
  func persistentTransportResponsesSurfaceGatewaySocketRejection() async throws {
    let socket = StubSocket(
      receivedTexts: ["{\"kind\":\"error\"}"]
    )
    let client = OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://orbit.example")!,
      session: URLSession(configuration: .ephemeral),
      socketFactory: { _, _ in socket },
      sleep: { _ in
        try await Task.sleep(for: .zero)
      }
    )
    let responses = try await client.persistentTransportResponses(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: OrbitPhase1RealtimeSubscriptionScope(
          workspaceSlug: "orbit",
          channelSlug: "command-center"
        )
      )
    )
    var iterator = responses.makeAsyncIterator()

    do {
      _ = try await iterator.next()
      Issue.record("Expected socket rejection")
    } catch let error as OrbitGatewayNetworkClientError {
      switch error {
      case .socketRejectedRequest:
        break
      case .invalidHTTPResponse,
        .unexpectedStatusCode,
        .invalidSocketURL,
        .invalidSocketMessage:
        Issue.record("Expected socket rejection, got \(error)")
      }
    }
  }

  @Test
  func appendCollaboratorResponseSendsContractAndDecodesCanonicalResult() async throws {
    let result = sampleCollaboratorResult()
    let client = makeClient { request in
      #expect(request.url?.path == "/api/orbit/room/responses")
      let body = try JSONDecoder().decode(
        OrbitGatewayAppendCollaboratorResponseRequest.self,
        from: try requestBody(for: request)
      )
      #expect(body.workspaceSlug == "orbit")
      #expect(body.contract?.authorizedSkillIDs == ["codex-cli"])
      #expect(body.contract?.reviewGateIDs == ["intent:partner-sync-review"])

      return try makeResponse(
        statusCode: 200,
        body: OrbitGatewayAppendCollaboratorResponse(result: result),
        url: try #require(request.url)
      )
    }

    let response = try await client.appendCollaboratorResponse(
      OrbitPhase1AppendCollaboratorResponseRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        workspacePersonaID: result.activation.resolvedWorkspacePersonaInstanceID,
        initiatedByParticipantID: "aj",
        triggerMessageID: result.activation.triggerMessageID,
        addressedTargetKind: .collaborator,
        addressedTargetReferenceID: result.activation.resolvedWorkspacePersonaInstanceID.uuidString,
        responseMode: .directAddress,
        body: result.message.body,
        contract: OrbitPhase1ResolvedContractPayload(
          directiveID: "maintain-partner-sync-and-handoffs",
          directiveSource: OrbitDirectiveSource.participantDefault.rawValue,
          kitIDs: ["trusted-partner-core"],
          authorizedSkillIDs: ["codex-cli"],
          requiredSkillIDs: ["codex-cli"],
          stopPointIDs: [],
          reviewGateIDs: ["intent:partner-sync-review"],
          memoryScopeIDs: []
        )
      )
    )

    #expect(response == result)
  }

  @Test
  func connectThrowsHelpfulErrorForGatewayFailure() async throws {
    let client = makeClient { request in
      try makeResponse(
        statusCode: 503,
        body: Data("gateway offline".utf8),
        url: try #require(request.url)
      )
    }

    do {
      _ = try await client.connect(
        request: OrbitPhase1RealtimeConnectRequest(
          scope: OrbitPhase1RealtimeSubscriptionScope(
            workspaceSlug: "orbit",
            channelSlug: "command-center"
          )
        )
      )
      Issue.record("Expected gateway failure")
    } catch let error as OrbitGatewayNetworkClientError {
      switch error {
      case .unexpectedStatusCode(let statusCode, let body):
        #expect(statusCode == 503)
        #expect(body == "gateway offline")
      case .invalidHTTPResponse:
        Issue.record("Expected HTTP status failure, not invalid response")
      case .invalidSocketURL,
        .invalidSocketMessage,
        .socketRejectedRequest:
        Issue.record("Expected HTTP status failure, got \(error)")
      }
    }
  }

  private func makeClient(
    handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
  ) -> OrbitGatewayNetworkClient {
    let host = "orbit-\(UUID().uuidString.lowercased())"
    TestURLProtocol.handlerBox.set(handler, forHost: host)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [TestURLProtocol.self]

    return OrbitGatewayNetworkClient(
      baseURL: URL(string: "http://\(host)")!,
      session: URLSession(configuration: configuration)
    )
  }

  private func makeResponse<ResponseBody: Encodable>(
    statusCode: Int,
    body: ResponseBody,
    url: URL
  ) throws -> (HTTPURLResponse, Data) {
    (
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!,
      try JSONEncoder().encode(body)
    )
  }

  private func makeResponse(
    statusCode: Int,
    body: Data,
    url: URL
  ) throws -> (HTTPURLResponse, Data) {
    (
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: ["Content-Type": "text/plain"]
      )!,
      body
    )
  }

  private func makeSocketPayload(
    _ payload: OrbitGatewayTransportResponse
  ) throws -> String {
    String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
  }

  private func sampleSession(
    snapshot: OrbitPhase1RealtimeSnapshot
  ) -> OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center"
      ),
      replayCursor: snapshot.replayCursor,
      connectedAt: Date(timeIntervalSince1970: 1_742_342_400),
      lastInteractionAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    return OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
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
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
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
          lastActivityAt: Date(timeIntervalSince1970: 1_742_342_400),
          createdAt: Date(timeIntervalSince1970: 1_742_342_400)
        ),
        messages: []
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: nil,
        lastEventCreatedAt: nil
      )
    )
  }

  private func sampleCollaboratorResult() -> OrbitPhase1AppendCollaboratorResponseResult {
    let snapshot = sampleSnapshot()
    let workspacePersonaID = snapshot.room.workspacePersonas[0].id
    let triggerMessageID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let message = OrbitMessageRecord(
      id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
      postID: snapshot.room.post.id,
      threadID: snapshot.room.thread.id,
      authorType: .workspacePersona,
      authorID: workspacePersonaID.uuidString,
      replyToMessageID: triggerMessageID,
      body: "Canonical collaborator response",
      messageFormat: .markdown,
      state: .completed,
      createdAt: Date(timeIntervalSince1970: 1_742_342_510),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_510)
    )
    let activation = OrbitPersonaActivationRecord(
      id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
      initiatedByParticipantType: .user,
      initiatedByParticipantID: "aj",
      workspaceID: snapshot.room.workspace.id,
      channelID: snapshot.room.channel.id,
      originPostID: snapshot.room.post.id,
      originThreadID: snapshot.room.thread.id,
      triggerMessageID: triggerMessageID,
      addressedTargetKind: .collaborator,
      addressedTargetReferenceID: workspacePersonaID.uuidString,
      resolvedWorkspacePersonaInstanceID: workspacePersonaID,
      responseMode: .directAddress,
      createdAt: Date(timeIntervalSince1970: 1_742_342_510)
    )
    let agentRun = OrbitAgentRunRecord(
      id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
      personaActivationID: activation.id,
      runnerKind: "local-bridge",
      status: .completed,
      startedAt: Date(timeIntervalSince1970: 1_742_342_510),
      completedAt: Date(timeIntervalSince1970: 1_742_342_510)
    )

    return OrbitPhase1AppendCollaboratorResponseResult(
      snapshot: OrbitPhase1RoomSnapshot(
        workspace: snapshot.room.workspace,
        channel: snapshot.room.channel,
        workspacePersonas: snapshot.room.workspacePersonas,
        post: snapshot.room.post,
        thread: snapshot.room.thread,
        messages: [message],
        personaActivations: [activation],
        agentRuns: [agentRun]
      ),
      message: message,
      activation: activation,
      agentRun: agentRun
    )
  }

  private func requestBody(
    for request: URLRequest
  ) throws -> Data {
    if let httpBody = request.httpBody {
      return httpBody
    }

    guard let stream = request.httpBodyStream else {
      throw URLError(.badServerResponse)
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    var data = Data()

    while stream.hasBytesAvailable {
      let readCount = stream.read(buffer, maxLength: bufferSize)

      if readCount < 0 {
        throw stream.streamError ?? URLError(.cannotDecodeRawData)
      }

      if readCount == 0 {
        break
      }

      data.append(buffer, count: readCount)
    }

    return data
  }
}

private actor StubSocket: OrbitGatewaySocketHandling {
  private(set) var sentTexts = [String]()
  private var receivedTexts: [String]
  private(set) var cancelCallCount = 0

  init(
    receivedTexts: [String]
  ) {
    self.receivedTexts = receivedTexts
  }

  func send(
    text: String
  ) async throws {
    sentTexts.append(text)
  }

  func receiveText() async throws -> String {
    guard !receivedTexts.isEmpty else {
      throw URLError(.cannotParseResponse)
    }

    return receivedTexts.removeFirst()
  }

  func cancel() async {
    cancelCallCount += 1
  }
}

private actor StubSleep {
  private let maxSleepsBeforeCancellation: Int
  private var sleepCount = 0

  init(
    maxSleepsBeforeCancellation: Int
  ) {
    self.maxSleepsBeforeCancellation = maxSleepsBeforeCancellation
  }

  func pause(
    for _: Duration
  ) async throws {
    sleepCount += 1

    if sleepCount > maxSleepsBeforeCancellation {
      throw CancellationError()
    }
  }
}

private final class CapturedURLBox: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: URL?

  var current: URL? {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  func set(
    _ url: URL
  ) {
    lock.lock()
    storage = url
    lock.unlock()
  }
}

private final class TestURLProtocolHandlerBox: @unchecked Sendable {
  private let lock = NSLock()
  private var handlers = [String: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)]()

  func set(
    _ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data),
    forHost host: String
  ) {
    lock.lock()
    handlers[host] = handler
    lock.unlock()
  }

  func current(
    forHost host: String
  ) -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
    lock.lock()
    defer { lock.unlock() }
    return handlers[host]
  }
}

private final class TestURLProtocol: URLProtocol, @unchecked Sendable {
  static let handlerBox = TestURLProtocolHandlerBox()

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      guard
        let host = request.url?.host,
        let handler = Self.handlerBox.current(forHost: host)
      else {
        throw URLError(.badServerResponse)
      }
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
