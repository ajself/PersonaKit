import Foundation

public struct OrbitPhase1RealtimeSession: Equatable, Sendable {
  public let scope: OrbitPhase1RealtimeSubscriptionScope
  public let replayCursor: OrbitPhase1ReplayCursor
  public let connectedAt: Date
  public let lastInteractionAt: Date

  public init(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    replayCursor: OrbitPhase1ReplayCursor,
    connectedAt: Date,
    lastInteractionAt: Date
  ) {
    self.scope = scope
    self.replayCursor = replayCursor
    self.connectedAt = connectedAt
    self.lastInteractionAt = lastInteractionAt
  }
}

public struct OrbitPhase1RealtimeSessionDelivery: Equatable, Sendable {
  public let session: OrbitPhase1RealtimeSession
  public let delivery: OrbitPhase1SubscriptionDelivery

  public init(
    session: OrbitPhase1RealtimeSession,
    delivery: OrbitPhase1SubscriptionDelivery
  ) {
    self.session = session
    self.delivery = delivery
  }
}

public struct OrbitPhase1RealtimePollingSessionService: Sendable {
  public let adapter: OrbitPhase1RealtimeSubscriptionAdapter
  public let staleAfter: TimeInterval
  public let now: @Sendable () -> Date

  public init(
    adapter: OrbitPhase1RealtimeSubscriptionAdapter,
    staleAfter: TimeInterval = 30,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.adapter = adapter
    self.staleAfter = staleAfter
    self.now = now
  }

  public func connect(
    handshake: OrbitPhase1SubscriptionHandshake
  ) async throws -> OrbitPhase1RealtimeSessionDelivery {
    let interactionDate = now()
    let delivery = try await adapter.start(handshake: handshake)
    let cursor = nextCursor(from: delivery)

    let session = OrbitPhase1RealtimeSession(
      scope: handshake.scope,
      replayCursor: cursor,
      connectedAt: interactionDate,
      lastInteractionAt: interactionDate
    )

    return OrbitPhase1RealtimeSessionDelivery(
      session: session,
      delivery: delivery
    )
  }

  public func poll(
    session: OrbitPhase1RealtimeSession
  ) async throws -> OrbitPhase1RealtimeSessionDelivery {
    let interactionDate = now()

    if interactionDate.timeIntervalSince(session.lastInteractionAt) > staleAfter {
      let replayResult = try await adapter.feedService.resync(
        scope: session.scope,
        reason: .staleClient
      )

      guard case .resync(let snapshot, let reason) = replayResult else {
        preconditionFailure("Resync path must return a resync result")
      }

      let delivery = OrbitPhase1SubscriptionDelivery.resync(snapshot, reason: reason)
      let updatedSession = OrbitPhase1RealtimeSession(
        scope: session.scope,
        replayCursor: snapshot.replayCursor,
        connectedAt: session.connectedAt,
        lastInteractionAt: interactionDate
      )

      return OrbitPhase1RealtimeSessionDelivery(
        session: updatedSession,
        delivery: delivery
      )
    }

    let delivery = try await adapter.start(
      handshake: OrbitPhase1SubscriptionHandshake(
        scope: session.scope,
        cursor: session.replayCursor
      )
    )

    let updatedSession = OrbitPhase1RealtimeSession(
      scope: session.scope,
      replayCursor: nextCursor(from: delivery),
      connectedAt: session.connectedAt,
      lastInteractionAt: interactionDate
    )

    return OrbitPhase1RealtimeSessionDelivery(
      session: updatedSession,
      delivery: delivery
    )
  }

  public func requiresResync(
    session: OrbitPhase1RealtimeSession
  ) -> Bool {
    now().timeIntervalSince(session.lastInteractionAt) > staleAfter
  }

  private func nextCursor(
    from delivery: OrbitPhase1SubscriptionDelivery
  ) -> OrbitPhase1ReplayCursor {
    switch delivery {
    case .bootstrap(let snapshot):
      return snapshot.replayCursor
    case .replay(_, let nextCursor):
      return nextCursor
    case .noChange(let cursor):
      return cursor
    case .resync(let snapshot, _):
      return snapshot.replayCursor
    }
  }
}
