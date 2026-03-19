import Foundation

public protocol OrbitPhase1RealtimeTransportServing: Sendable {
  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse
}

public struct OrbitPhase1RealtimeConnectRequest: Equatable, Sendable {
  public let scope: OrbitPhase1RealtimeSubscriptionScope
  public let cursor: OrbitPhase1ReplayCursor?

  public init(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor? = nil
  ) {
    self.scope = scope
    self.cursor = cursor
  }
}

public struct OrbitPhase1RealtimePollRequest: Equatable, Sendable {
  public let session: OrbitPhase1RealtimeSession

  public init(
    session: OrbitPhase1RealtimeSession
  ) {
    self.session = session
  }
}

public enum OrbitPhase1RealtimeTransportResponse: Equatable, Sendable {
  case bootstrap(OrbitPhase1RealtimeSession, OrbitPhase1RealtimeSnapshot)
  case replay(OrbitPhase1RealtimeSession, [OrbitPhase1RealtimeEventEnvelope])
  case noChange(OrbitPhase1RealtimeSession)
  case resync(OrbitPhase1RealtimeSession, OrbitPhase1RealtimeSnapshot, OrbitPhase1RealtimeResyncReason)
}

public struct OrbitPhase1RealtimeTransportAdapter: Sendable {
  public let pollingService: OrbitPhase1RealtimePollingSessionService

  public init(
    pollingService: OrbitPhase1RealtimePollingSessionService
  ) {
    self.pollingService = pollingService
  }

  public func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    let delivery = try await pollingService.connect(
      handshake: OrbitPhase1SubscriptionHandshake(
        scope: request.scope,
        cursor: request.cursor
      )
    )

    return map(delivery)
  }

  public func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    let delivery = try await pollingService.poll(session: request.session)
    return map(delivery)
  }

  private func map(
    _ delivery: OrbitPhase1RealtimeSessionDelivery
  ) -> OrbitPhase1RealtimeTransportResponse {
    switch delivery.delivery {
    case .bootstrap(let snapshot):
      return .bootstrap(delivery.session, snapshot)
    case .replay(let events, _):
      return .replay(delivery.session, events)
    case .noChange:
      return .noChange(delivery.session)
    case .resync(let snapshot, let reason):
      return .resync(delivery.session, snapshot, reason)
    }
  }
}

extension OrbitPhase1RealtimeTransportAdapter: OrbitPhase1RealtimeTransportServing {}
