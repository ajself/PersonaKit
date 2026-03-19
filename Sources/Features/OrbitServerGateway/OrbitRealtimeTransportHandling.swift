import Foundation
import OrbitServerRuntime

public protocol OrbitRealtimeTransportHandling: Sendable {
  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse
}

extension OrbitPhase1RealtimeTransportAdapter: OrbitRealtimeTransportHandling {}

public protocol OrbitSystemMessageHandling: Sendable {
  func appendSystemMessage(
    _ request: OrbitPhase1AppendSystemMessageRequest
  ) async throws -> OrbitPhase1AppendSystemMessageResult
}

extension OrbitPhase1SystemMessageService: OrbitSystemMessageHandling {}

public protocol OrbitActivationFailureHandling: Sendable {
  func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult
}

extension OrbitPhase1ActivationFailureService: OrbitActivationFailureHandling {}

public protocol OrbitCollaboratorResponseHandling: Sendable {
  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult
}

extension OrbitPhase1CollaboratorResponseService: OrbitCollaboratorResponseHandling {}
