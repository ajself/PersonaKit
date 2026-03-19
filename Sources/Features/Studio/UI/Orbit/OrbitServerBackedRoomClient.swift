import Foundation
import OrbitServerRuntime

struct OrbitServerBackedRoomClient: Sendable {
  let connectHandler: @Sendable (OrbitPhase1RealtimeSubscriptionScope) async throws -> OrbitPhase1RealtimeTransportResponse
  let pollHandler: @Sendable (OrbitPhase1RealtimeSession) async throws -> OrbitPhase1RealtimeTransportResponse
  let appendHandler: @Sendable (OrbitPhase1AppendUserMessageRequest) async throws -> OrbitPhase1AppendUserMessageResult

  init<Transport: OrbitPhase1RealtimeTransportServing, Writer: OrbitPhase1RoomWriteServing>(
    transport: Transport,
    roomWriter: Writer
  ) {
    self.connectHandler = { scope in
      try await transport.connect(
        request: OrbitPhase1RealtimeConnectRequest(scope: scope)
      )
    }
    self.pollHandler = { session in
      try await transport.poll(
        request: OrbitPhase1RealtimePollRequest(session: session)
      )
    }
    self.appendHandler = { request in
      try await roomWriter.appendUserMessage(request)
    }
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
}
