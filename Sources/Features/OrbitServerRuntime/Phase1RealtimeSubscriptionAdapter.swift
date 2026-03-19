import Foundation

public struct OrbitPhase1SubscriptionHandshake: Equatable, Sendable {
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

public enum OrbitPhase1SubscriptionDelivery: Equatable, Sendable {
  case bootstrap(OrbitPhase1RealtimeSnapshot)
  case replay([OrbitPhase1RealtimeEventEnvelope], nextCursor: OrbitPhase1ReplayCursor)
  case noChange(OrbitPhase1ReplayCursor)
  case resync(OrbitPhase1RealtimeSnapshot, reason: OrbitPhase1RealtimeResyncReason)
}

public struct OrbitPhase1RealtimeSubscriptionAdapter: Sendable {
  public let feedService: OrbitPhase1RealtimeFeedService

  public init(
    feedService: OrbitPhase1RealtimeFeedService
  ) {
    self.feedService = feedService
  }

  public func start(
    handshake: OrbitPhase1SubscriptionHandshake
  ) async throws -> OrbitPhase1SubscriptionDelivery {
    let snapshot = try await feedService.bootstrap(scope: handshake.scope)

    guard let cursor = handshake.cursor else {
      return .bootstrap(snapshot)
    }

    if let mismatch = feedService.validate(snapshot: snapshot, against: cursor) {
      return .resync(snapshot, reason: mismatch)
    }

    let replayResult = try await feedService.replay(
      scope: handshake.scope,
      cursor: cursor
    )

    switch replayResult {
    case .noChange(let nextCursor):
      return .noChange(nextCursor)
    case .events(let events, let nextCursor):
      return .replay(events, nextCursor: nextCursor)
    case .resync(let resyncSnapshot, let reason):
      return .resync(resyncSnapshot, reason: reason)
    }
  }
}
