import Foundation
import OrbitServerRuntime

struct OrbitServerBackedRoomClient: Sendable {
  let connectHandler: @Sendable (OrbitPhase1RealtimeSubscriptionScope) async throws -> OrbitPhase1RealtimeTransportResponse
  let pollHandler: @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse
  let appendHandler: @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult
  let appendSystemHandler: @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult
  let appendCollaboratorHandler: @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult
  let appendFailureHandler: @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult

  init(
    connectHandler: @escaping @Sendable (OrbitPhase1RealtimeSubscriptionScope) async throws -> OrbitPhase1RealtimeTransportResponse,
    pollHandler: @escaping @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse,
    appendHandler: @escaping @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult,
    appendSystemHandler: @escaping @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult,
    appendCollaboratorHandler: @escaping @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult,
    appendFailureHandler: @escaping @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult
  ) {
    self.connectHandler = connectHandler
    self.pollHandler = pollHandler
    self.appendHandler = appendHandler
    self.appendSystemHandler = appendSystemHandler
    self.appendCollaboratorHandler = appendCollaboratorHandler
    self.appendFailureHandler = appendFailureHandler
  }

  init<
    Transport: OrbitPhase1RealtimeTransportServing,
    Writer: OrbitPhase1RoomWriteServing,
    SystemWriter: OrbitPhase1SystemMessageServing,
    FailureWriter: OrbitPhase1ActivationFailureServing,
    CollaboratorWriter: OrbitPhase1CollaboratorResponseServing
  >(
    transport: Transport,
    roomWriter: Writer,
    systemWriter: SystemWriter,
    failureWriter: FailureWriter,
    collaboratorWriter: CollaboratorWriter
  ) {
    self.init(
      connectHandler: { scope in
        try await transport.connect(
          request: OrbitPhase1RealtimeConnectRequest(scope: scope)
        )
      },
      pollHandler: { session in
        try await transport.poll(
          request: OrbitPhase1RealtimePollRequest(session: session)
        )
      },
      appendHandler: { request in
        try await roomWriter.appendUserMessage(request)
      },
      appendSystemHandler: { request in
        try await systemWriter.appendSystemMessage(request)
      },
      appendCollaboratorHandler: { request in
        try await collaboratorWriter.appendCollaboratorResponse(request)
      },
      appendFailureHandler: { request in
        try await failureWriter.appendActivationFailure(request)
      }
    )
  }

  func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await connectHandler(scope)
  }

  func poll(
    session: OrbitPhase1RealtimeSession
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await pollHandler(session)
  }

  func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult {
    try await appendHandler(request)
  }

  func appendSystemMessage(
    _ request: OrbitPhase1AppendSystemMessageRequest
  ) async throws -> OrbitPhase1AppendSystemMessageResult {
    try await appendSystemHandler(request)
  }

  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    try await appendCollaboratorHandler(request)
  }

  func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult {
    try await appendFailureHandler(request)
  }
}
