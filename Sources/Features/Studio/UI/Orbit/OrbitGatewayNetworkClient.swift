import Foundation
import OrbitServerGateway
import OrbitServerRuntime

enum OrbitGatewayNetworkClientError: LocalizedError {
  case invalidHTTPResponse
  case unexpectedStatusCode(Int, String)
  case invalidSocketURL(String)
  case invalidSocketMessage
  case socketRejectedRequest

  var errorDescription: String? {
    switch self {
    case .invalidHTTPResponse:
      return "Orbit gateway returned an invalid HTTP response."
    case .unexpectedStatusCode(let statusCode, let body):
      let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

      if trimmedBody.isEmpty {
        return "Orbit gateway returned HTTP \(statusCode)."
      }

      return "Orbit gateway returned HTTP \(statusCode): \(trimmedBody)"
    case .invalidSocketURL(let urlString):
      return "Orbit could not open a persistent gateway socket from \(urlString)."
    case .invalidSocketMessage:
      return "Orbit gateway returned an unreadable persistent transport payload."
    case .socketRejectedRequest:
      return "Orbit gateway rejected the persistent transport request."
    }
  }
}

protocol OrbitGatewaySocketHandling: Sendable {
  func send(text: String) async throws
  func receiveText() async throws -> String
  func cancel() async
}

actor OrbitGatewayURLSessionSocket: OrbitGatewaySocketHandling {
  private let task: URLSessionWebSocketTask

  init(
    task: URLSessionWebSocketTask
  ) {
    self.task = task
    task.resume()
  }

  func send(
    text: String
  ) async throws {
    try await task.send(.string(text))
  }

  func receiveText() async throws -> String {
    switch try await task.receive() {
    case .string(let text):
      return text
    case .data(let data):
      return String(decoding: data, as: UTF8.self)
    @unknown default:
      throw OrbitGatewayNetworkClientError.invalidSocketMessage
    }
  }

  func cancel() async {
    task.cancel(with: .goingAway, reason: nil)
  }
}

struct OrbitGatewaySocketErrorPayload: Decodable {
  let kind: String
}

actor OrbitGatewayNetworkClient {
  private let baseURL: URL
  private let session: URLSession
  private let socketFactory: @Sendable (URLSession, URL) -> any OrbitGatewaySocketHandling
  private let sleep: @Sendable (Duration) async throws -> Void

  init(
    baseURL: URL,
    session: URLSession = .shared,
    socketFactory: @escaping @Sendable (URLSession, URL) -> any OrbitGatewaySocketHandling = { session, url in
      OrbitGatewayURLSessionSocket(task: session.webSocketTask(with: url))
    },
    sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
      try await Task.sleep(for: duration)
    }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.socketFactory = socketFactory
    self.sleep = sleep
  }

  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    let response: OrbitGatewayTransportResponse = try await post(
      "api/orbit/realtime/connect",
      body: OrbitGatewayConnectRequest(
        workspaceSlug: request.scope.workspaceSlug,
        channelSlug: request.scope.channelSlug,
        postID: request.scope.postID,
        cursorWorkspaceID: request.cursor?.workspaceID,
        cursorEventID: request.cursor?.lastEventID,
        cursorEventCreatedAt: request.cursor?.lastEventCreatedAt
      )
    )

    return response.response
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    let response: OrbitGatewayTransportResponse = try await post(
      "api/orbit/realtime/poll",
      body: OrbitGatewayPollRequest(
        session: OrbitGatewaySessionPayload(
          workspaceSlug: request.session.scope.workspaceSlug,
          channelSlug: request.session.scope.channelSlug,
          postID: request.session.scope.postID,
          workspaceID: request.session.replayCursor.workspaceID,
          cursorEventID: request.session.replayCursor.lastEventID,
          cursorEventCreatedAt: request.session.replayCursor.lastEventCreatedAt,
          connectedAt: request.session.connectedAt,
          lastInteractionAt: request.session.lastInteractionAt
        )
      )
    )

    return response.response
  }

  func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult {
    let response: OrbitGatewayAppendMessageResponse = try await post(
      "api/orbit/room/messages",
      body: OrbitGatewayAppendMessageRequest(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        postID: request.postID,
        authorID: request.authorID,
        body: request.body
      )
    )

    return response.result
  }

  func appendSystemMessage(
    _ request: OrbitPhase1AppendSystemMessageRequest
  ) async throws -> OrbitPhase1AppendSystemMessageResult {
    let response: OrbitGatewayAppendSystemMessageResponse = try await post(
      "api/orbit/room/system-messages",
      body: OrbitGatewayAppendSystemMessageRequest(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        postID: request.postID,
        body: request.body,
        replyToMessageID: request.replyToMessageID
      )
    )

    return response.result
  }

  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    let response: OrbitGatewayAppendCollaboratorResponse = try await post(
      "api/orbit/room/responses",
      body: OrbitGatewayAppendCollaboratorResponseRequest(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        postID: request.postID,
        workspacePersonaID: request.workspacePersonaID,
        initiatedByParticipantID: request.initiatedByParticipantID,
        triggerMessageID: request.triggerMessageID,
        addressedTargetKind: request.addressedTargetKind.rawValue,
        addressedTargetReferenceID: request.addressedTargetReferenceID,
        responseMode: request.responseMode.rawValue,
        body: request.body,
        contract: request.contract,
        runnerKind: request.runnerKind
      )
    )

    return response.result
  }

  func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult {
    let response: OrbitGatewayAppendActivationFailureResponse = try await post(
      "api/orbit/room/activation-failures",
      body: OrbitGatewayAppendActivationFailureRequest(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        postID: request.postID,
        initiatedByParticipantID: request.initiatedByParticipantID,
        triggerMessageID: request.triggerMessageID,
        failure: request.failure
      )
    )

    return response.result
  }

  func appendMeetingPromotionEvent(
    _ request: OrbitPhase1AppendMeetingPromotionEventRequest
  ) async throws -> OrbitPhase1AppendMeetingPromotionEventResult {
    let response: OrbitGatewayAppendMeetingPromotionEventResponse = try await post(
      "api/orbit/room/meeting-promotions",
      body: OrbitGatewayAppendMeetingPromotionEventRequest(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        postID: request.postID,
        promotion: request.promotion
      )
    )

    return response.result
  }

  func createMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1CreateMeetingRoomResult {
    let response: OrbitGatewayCreateMeetingRoomResponse = try await post(
      "api/orbit/room/meetings",
      body: OrbitGatewayCreateMeetingRoomRequest(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        title: request.title,
        meetingType: request.meetingType.rawValue,
        startedByParticipantType: request.startedByParticipantType.rawValue,
        startedByParticipantID: request.startedByParticipantID,
        members: request.members
      )
    )

    return response.result
  }

  func promoteMeetingRoom(
    _ request: OrbitPhase1PromoteMeetingRoomRequest
  ) async throws -> OrbitPhase1PromoteMeetingRoomResult {
    let response: OrbitGatewayPromoteMeetingRoomResponse = try await post(
      "api/orbit/room/promoted-meetings",
      body: OrbitGatewayPromoteMeetingRoomRequest(
        originPostID: request.originPostID,
        meeting: OrbitGatewayCreateMeetingRoomRequest(
          workspaceSlug: request.meeting.workspaceSlug,
          channelSlug: request.meeting.channelSlug,
          title: request.meeting.title,
          meetingType: request.meeting.meetingType.rawValue,
          startedByParticipantType: request.meeting.startedByParticipantType.rawValue,
          startedByParticipantID: request.meeting.startedByParticipantID,
          members: request.meeting.members
        ),
        promotion: request.promotion
      )
    )

    return response.result
  }

  func persistentTransportResponses(
    request: OrbitPhase1RealtimeConnectRequest,
    pollInterval: Duration = .seconds(2)
  ) throws -> OrbitServerBackedRoomResponseStream {
    let socketURL = try makeSocketURL(for: request)
    let session = self.session
    let socketFactory = self.socketFactory
    let sleep = self.sleep

    return AsyncThrowingStream { continuation in
      let socketTask = Task {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let socket = socketFactory(session, socketURL)

        do {
          let bootstrapResponse = try await Self.exchange(
            OrbitGatewayWebSocketClientMessage(kind: .bootstrap),
            over: socket,
            encoder: encoder,
            decoder: decoder
          )
          continuation.yield(bootstrapResponse)

          var currentSession = Self.session(from: bootstrapResponse)

          while !Task.isCancelled {
            try await sleep(pollInterval)

            guard !Task.isCancelled else {
              break
            }

            let pollResponse = try await Self.exchange(
              OrbitGatewayWebSocketClientMessage(
                kind: .poll,
                session: OrbitGatewaySessionPayload(
                  workspaceSlug: currentSession.scope.workspaceSlug,
                  channelSlug: currentSession.scope.channelSlug,
                  postID: currentSession.scope.postID,
                  workspaceID: currentSession.replayCursor.workspaceID,
                  cursorEventID: currentSession.replayCursor.lastEventID,
                  cursorEventCreatedAt: currentSession.replayCursor.lastEventCreatedAt,
                  connectedAt: currentSession.connectedAt,
                  lastInteractionAt: currentSession.lastInteractionAt
                )
              ),
              over: socket,
              encoder: encoder,
              decoder: decoder
            )
            continuation.yield(pollResponse)
            currentSession = Self.session(from: pollResponse)
          }

          continuation.finish()
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }

        await socket.cancel()
      }

      continuation.onTermination = { @Sendable _ in
        socketTask.cancel()
      }
    }
  }

  private func post<RequestBody: Encodable, ResponseBody: Decodable>(
    _ path: String,
    body: RequestBody
  ) async throws -> ResponseBody {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try Self.httpEncoder.encode(body)

    let (data, urlResponse) = try await session.data(for: request)

    guard let httpResponse = urlResponse as? HTTPURLResponse else {
      throw OrbitGatewayNetworkClientError.invalidHTTPResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      throw OrbitGatewayNetworkClientError.unexpectedStatusCode(
        httpResponse.statusCode,
        String(decoding: data, as: UTF8.self)
      )
    }

    return try Self.httpDecoder.decode(ResponseBody.self, from: data)
  }

  private func makeSocketURL(
    for request: OrbitPhase1RealtimeConnectRequest
  ) throws -> URL {
    guard
      var components = URLComponents(
        url: baseURL.appending(path: "api/orbit/realtime/socket"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw OrbitGatewayNetworkClientError.invalidSocketURL(baseURL.absoluteString)
    }

    switch components.scheme {
    case "http":
      components.scheme = "ws"
    case "https":
      components.scheme = "wss"
    case "ws", "wss":
      break
    default:
      throw OrbitGatewayNetworkClientError.invalidSocketURL(baseURL.absoluteString)
    }

    var queryItems = [
      URLQueryItem(name: "workspaceSlug", value: request.scope.workspaceSlug),
      URLQueryItem(name: "channelSlug", value: request.scope.channelSlug),
    ]

    if let postID = request.scope.postID {
      queryItems.append(
        URLQueryItem(
          name: "postID",
          value: postID.uuidString
        )
      )
    }

    if let cursor = request.cursor {
      queryItems.append(
        URLQueryItem(
          name: "cursorWorkspaceID",
          value: cursor.workspaceID.uuidString
        )
      )
      queryItems.append(
        URLQueryItem(
          name: "cursorEventID",
          value: cursor.lastEventID?.uuidString
        )
      )
      queryItems.append(
        URLQueryItem(
          name: "cursorEventCreatedAt",
          value: cursor.lastEventCreatedAt.map { String($0.timeIntervalSince1970) }
        )
      )
    }

    components.queryItems = queryItems

    guard let socketURL = components.url else {
      throw OrbitGatewayNetworkClientError.invalidSocketURL(baseURL.absoluteString)
    }

    return socketURL
  }

  private static func exchange(
    _ message: OrbitGatewayWebSocketClientMessage,
    over socket: any OrbitGatewaySocketHandling,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    let payload = try encoder.encode(message)
    try await socket.send(text: String(decoding: payload, as: UTF8.self))

    let text = try await socket.receiveText()
    let data = Data(text.utf8)

    if
      let errorPayload = try? decoder.decode(OrbitGatewaySocketErrorPayload.self, from: data),
      errorPayload.kind == "error"
    {
      throw OrbitGatewayNetworkClientError.socketRejectedRequest
    }

    guard
      let response = try? decoder.decode(
        OrbitGatewayTransportResponse.self,
        from: data
      )
    else {
      throw OrbitGatewayNetworkClientError.invalidSocketMessage
    }

    return response.response
  }

  private static func session(
    from response: OrbitPhase1RealtimeTransportResponse
  ) -> OrbitPhase1RealtimeSession {
    switch response {
    case .bootstrap(let session, _),
      .replay(let session, _),
      .noChange(let session),
      .resync(let session, _, _):
      return session
    }
  }

  private static let httpEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let httpDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
