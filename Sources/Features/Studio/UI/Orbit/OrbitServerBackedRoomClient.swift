import Foundation
import OrbitServerRuntime

typealias OrbitServerBackedRoomResponseStream = AsyncThrowingStream<
  OrbitPhase1RealtimeTransportResponse,
  Error
>

private enum OrbitServerBackedRoomClientError: Error {
  case meetingCreationUnavailable
}

struct OrbitServerBackedRoomClient: Sendable {
  let connectHandler: @Sendable (OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse
  let pollHandler: @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse
  let responseStreamHandler: (@Sendable (OrbitPhase1RealtimeConnectRequest, Duration) async -> OrbitServerBackedRoomResponseStream?)?
  let appendHandler: @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult
  let appendSystemHandler: @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult
  let appendCollaboratorHandler: @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult
  let appendFailureHandler: @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult
  let createMeetingHandler: @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1CreateMeetingRoomResult

  init(
    connectHandler: @escaping @Sendable (OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse,
    pollHandler: @escaping @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse,
    responseStreamHandler: (@Sendable (OrbitPhase1RealtimeConnectRequest, Duration) async -> OrbitServerBackedRoomResponseStream?)? = nil,
    appendHandler: @escaping @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult,
    appendSystemHandler: @escaping @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult,
    appendCollaboratorHandler: @escaping @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult,
    appendFailureHandler: @escaping @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult,
    createMeetingHandler: @escaping @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1CreateMeetingRoomResult = { _ in
      throw OrbitServerBackedRoomClientError.meetingCreationUnavailable
    }
  ) {
    self.connectHandler = connectHandler
    self.pollHandler = pollHandler
    self.responseStreamHandler = responseStreamHandler
    self.appendHandler = appendHandler
    self.appendSystemHandler = appendSystemHandler
    self.appendCollaboratorHandler = appendCollaboratorHandler
    self.appendFailureHandler = appendFailureHandler
    self.createMeetingHandler = createMeetingHandler
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
      connectHandler: { request in
        try await transport.connect(request: request)
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

  init<
    Transport: OrbitPhase1RealtimeTransportServing,
    Writer: OrbitPhase1RoomWriteServing,
    SystemWriter: OrbitPhase1SystemMessageServing,
    FailureWriter: OrbitPhase1ActivationFailureServing,
    CollaboratorWriter: OrbitPhase1CollaboratorResponseServing,
    MeetingCreator: OrbitPhase1MeetingRoomCreationServing
  >(
    transport: Transport,
    roomWriter: Writer,
    systemWriter: SystemWriter,
    failureWriter: FailureWriter,
    collaboratorWriter: CollaboratorWriter,
    meetingCreator: MeetingCreator
  ) {
    self.init(
      connectHandler: { request in
        try await transport.connect(request: request)
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
      },
      createMeetingHandler: { request in
        try await meetingCreator.createMeetingRoom(request)
      }
    )
  }

  func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor? = nil
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await connectHandler(
      OrbitPhase1RealtimeConnectRequest(
        scope: scope,
        cursor: cursor
      )
    )
  }

  func poll(
    session: OrbitPhase1RealtimeSession
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    try await pollHandler(session)
  }

  func persistentTransportResponses(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor? = nil,
    pollInterval: Duration = .seconds(2)
  ) async -> OrbitServerBackedRoomResponseStream? {
    guard let responseStreamHandler else {
      return nil
    }

    return await responseStreamHandler(
      OrbitPhase1RealtimeConnectRequest(
        scope: scope,
        cursor: cursor
      ),
      pollInterval
    )
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

  func createMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1CreateMeetingRoomResult {
    try await createMeetingHandler(request)
  }
}
