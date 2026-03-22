import Foundation
import OrbitServerRuntime

typealias OrbitServerBackedRoomResponseStream = AsyncThrowingStream<
  OrbitPhase1RealtimeTransportResponse,
  Error
>

private enum OrbitServerBackedRoomClientError: Error {
  case meetingCreationUnavailable
  case meetingPromotionUnavailable
  case meetingRoomPromotionUnavailable
  case meetingCompletionUnavailable
}

struct OrbitServerBackedRoomClient: Sendable {
  let connectHandler: @Sendable (OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse
  let pollHandler: @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse
  let responseStreamHandler: (@Sendable (OrbitPhase1RealtimeConnectRequest, Duration) async -> OrbitServerBackedRoomResponseStream?)?
  let appendHandler: @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult
  let appendSystemHandler: @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult
  let appendCollaboratorHandler: @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult
  let appendFailureHandler: @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult
  let appendMeetingPromotionHandler: @Sendable (OrbitPhase1AppendMeetingPromotionEventRequest) async throws -> OrbitPhase1AppendMeetingPromotionEventResult
  let promoteMeetingHandler: @Sendable (OrbitPhase1PromoteMeetingRoomRequest) async throws -> OrbitPhase1PromoteMeetingRoomResult
  let createMeetingHandler: @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1CreateMeetingRoomResult
  let completeMeetingHandler: @Sendable (OrbitPhase1CompleteMeetingRequest) async throws -> OrbitPhase1CompleteMeetingResult

  init(
    connectHandler: @escaping @Sendable (OrbitPhase1RealtimeConnectRequest) async throws -> OrbitPhase1RealtimeTransportResponse,
    pollHandler: @escaping @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse,
    responseStreamHandler: (@Sendable (OrbitPhase1RealtimeConnectRequest, Duration) async -> OrbitServerBackedRoomResponseStream?)? = nil,
    appendHandler: @escaping @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult,
    appendSystemHandler: @escaping @Sendable (OrbitPhase1AppendSystemMessageRequest) async throws -> OrbitPhase1AppendSystemMessageResult,
    appendCollaboratorHandler: @escaping @Sendable (OrbitPhase1AppendCollaboratorResponseRequest) async throws -> OrbitPhase1AppendCollaboratorResponseResult,
    appendFailureHandler: @escaping @Sendable (OrbitPhase1AppendActivationFailureRequest) async throws -> OrbitPhase1AppendActivationFailureResult,
    appendMeetingPromotionHandler: @escaping @Sendable (OrbitPhase1AppendMeetingPromotionEventRequest) async throws -> OrbitPhase1AppendMeetingPromotionEventResult = { _ in
      throw OrbitServerBackedRoomClientError.meetingPromotionUnavailable
    },
    promoteMeetingHandler: @escaping @Sendable (OrbitPhase1PromoteMeetingRoomRequest) async throws -> OrbitPhase1PromoteMeetingRoomResult = { _ in
      throw OrbitServerBackedRoomClientError.meetingRoomPromotionUnavailable
    },
    createMeetingHandler: @escaping @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1CreateMeetingRoomResult = { _ in
      throw OrbitServerBackedRoomClientError.meetingCreationUnavailable
    },
    completeMeetingHandler: @escaping @Sendable (OrbitPhase1CompleteMeetingRequest) async throws -> OrbitPhase1CompleteMeetingResult = { _ in
      throw OrbitServerBackedRoomClientError.meetingCompletionUnavailable
    }
  ) {
    self.connectHandler = connectHandler
    self.pollHandler = pollHandler
    self.responseStreamHandler = responseStreamHandler
    self.appendHandler = appendHandler
    self.appendSystemHandler = appendSystemHandler
    self.appendCollaboratorHandler = appendCollaboratorHandler
    self.appendFailureHandler = appendFailureHandler
    self.appendMeetingPromotionHandler = appendMeetingPromotionHandler
    self.promoteMeetingHandler = promoteMeetingHandler
    self.createMeetingHandler = createMeetingHandler
    self.completeMeetingHandler = completeMeetingHandler
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
    PromotionWriter: OrbitPhase1MeetingPromotionEventServing,
    CollaboratorWriter: OrbitPhase1CollaboratorResponseServing
  >(
    transport: Transport,
    roomWriter: Writer,
    systemWriter: SystemWriter,
    failureWriter: FailureWriter,
    promotionWriter: PromotionWriter,
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
      },
      appendMeetingPromotionHandler: { request in
        try await promotionWriter.appendMeetingPromotionEvent(request)
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

  init<
    Transport: OrbitPhase1RealtimeTransportServing,
    Writer: OrbitPhase1RoomWriteServing,
    SystemWriter: OrbitPhase1SystemMessageServing,
    FailureWriter: OrbitPhase1ActivationFailureServing,
    PromotionWriter: OrbitPhase1MeetingPromotionEventServing,
    MeetingPromoter: OrbitPhase1MeetingRoomPromotionServing,
    CollaboratorWriter: OrbitPhase1CollaboratorResponseServing,
    MeetingCreator: OrbitPhase1MeetingRoomCreationServing
  >(
    transport: Transport,
    roomWriter: Writer,
    systemWriter: SystemWriter,
    failureWriter: FailureWriter,
    promotionWriter: PromotionWriter,
    meetingPromoter: MeetingPromoter,
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
      appendMeetingPromotionHandler: { request in
        try await promotionWriter.appendMeetingPromotionEvent(request)
      },
      promoteMeetingHandler: { request in
        try await meetingPromoter.promoteMeetingRoom(request)
      },
      createMeetingHandler: { request in
        try await meetingCreator.createMeetingRoom(request)
      }
    )
  }

  init<
    Transport: OrbitPhase1RealtimeTransportServing,
    Writer: OrbitPhase1RoomWriteServing,
    SystemWriter: OrbitPhase1SystemMessageServing,
    FailureWriter: OrbitPhase1ActivationFailureServing,
    PromotionWriter: OrbitPhase1MeetingPromotionEventServing,
    MeetingPromoter: OrbitPhase1MeetingRoomPromotionServing,
    CollaboratorWriter: OrbitPhase1CollaboratorResponseServing,
    MeetingCreator: OrbitPhase1MeetingRoomCreationServing,
    MeetingCompleter: OrbitPhase1MeetingCompletionServing
  >(
    transport: Transport,
    roomWriter: Writer,
    systemWriter: SystemWriter,
    failureWriter: FailureWriter,
    promotionWriter: PromotionWriter,
    meetingPromoter: MeetingPromoter,
    collaboratorWriter: CollaboratorWriter,
    meetingCreator: MeetingCreator,
    meetingCompleter: MeetingCompleter
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
      appendMeetingPromotionHandler: { request in
        try await promotionWriter.appendMeetingPromotionEvent(request)
      },
      promoteMeetingHandler: { request in
        try await meetingPromoter.promoteMeetingRoom(request)
      },
      createMeetingHandler: { request in
        try await meetingCreator.createMeetingRoom(request)
      },
      completeMeetingHandler: { request in
        try await meetingCompleter.completeMeeting(request)
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

  func appendMeetingPromotionEvent(
    _ request: OrbitPhase1AppendMeetingPromotionEventRequest
  ) async throws -> OrbitPhase1AppendMeetingPromotionEventResult {
    try await appendMeetingPromotionHandler(request)
  }

  func promoteMeetingRoom(
    _ request: OrbitPhase1PromoteMeetingRoomRequest
  ) async throws -> OrbitPhase1PromoteMeetingRoomResult {
    try await promoteMeetingHandler(request)
  }

  func createMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1CreateMeetingRoomResult {
    try await createMeetingHandler(request)
  }

  func completeMeeting(
    _ request: OrbitPhase1CompleteMeetingRequest
  ) async throws -> OrbitPhase1CompleteMeetingResult {
    try await completeMeetingHandler(request)
  }
}
