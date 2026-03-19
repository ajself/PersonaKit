import Foundation
import OrbitServerGateway
import OrbitServerRuntime

enum OrbitGatewayNetworkClientError: LocalizedError {
  case invalidHTTPResponse
  case unexpectedStatusCode(Int, String)

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
    }
  }
}

actor OrbitGatewayNetworkClient {
  private let baseURL: URL
  private let session: URLSession

  init(
    baseURL: URL,
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.session = session
  }

  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    let response: OrbitGatewayTransportResponse = try await post(
      "api/orbit/realtime/connect",
      body: OrbitGatewayConnectRequest(
        workspaceSlug: request.scope.workspaceSlug,
        channelSlug: request.scope.channelSlug,
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
        initiatedByParticipantID: request.initiatedByParticipantID,
        triggerMessageID: request.triggerMessageID,
        failure: request.failure
      )
    )

    return response.result
  }

  private func post<RequestBody: Encodable, ResponseBody: Decodable>(
    _ path: String,
    body: RequestBody
  ) async throws -> ResponseBody {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONEncoder().encode(body)

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

    return try JSONDecoder().decode(ResponseBody.self, from: data)
  }
}
