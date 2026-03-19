import Foundation

public struct OrbitPhase1RealtimeSubscriptionScope: Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String

  public init(
    workspaceSlug: String,
    channelSlug: String
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
  }
}

public struct OrbitPhase1RealtimeReplayBatch: Equatable, Sendable {
  public let events: [OrbitPhase1RealtimeEventEnvelope]
  public let hasGap: Bool

  public init(
    events: [OrbitPhase1RealtimeEventEnvelope],
    hasGap: Bool = false
  ) {
    self.events = events
    self.hasGap = hasGap
  }
}

public enum OrbitPhase1RealtimeResyncReason: String, Equatable, Sendable {
  case gapDetected = "gap-detected"
  case staleClient = "stale-client"
  case workspaceMismatch = "workspace-mismatch"
  case inconsistentReplayBatch = "inconsistent-replay-batch"
}

public enum OrbitPhase1RealtimeReplayResult: Equatable, Sendable {
  case noChange(cursor: OrbitPhase1ReplayCursor)
  case events([OrbitPhase1RealtimeEventEnvelope], nextCursor: OrbitPhase1ReplayCursor)
  case resync(snapshot: OrbitPhase1RealtimeSnapshot, reason: OrbitPhase1RealtimeResyncReason)
}

public enum OrbitPhase1RealtimeFeedError: Error, Equatable {
  case snapshotUnavailable
}

public struct OrbitPhase1RealtimeFeedService: Sendable {
  public typealias SnapshotLoader = @Sendable (OrbitPhase1RealtimeSubscriptionScope) async throws -> OrbitPhase1RealtimeSnapshot?
  public typealias ReplayBatchLoader = @Sendable (OrbitPhase1RealtimeSubscriptionScope, OrbitPhase1ReplayCursor) async throws -> OrbitPhase1RealtimeReplayBatch

  public let loadSnapshot: SnapshotLoader
  public let loadReplayBatch: ReplayBatchLoader

  public init(
    loadSnapshot: @escaping SnapshotLoader,
    loadReplayBatch: @escaping ReplayBatchLoader
  ) {
    self.loadSnapshot = loadSnapshot
    self.loadReplayBatch = loadReplayBatch
  }

  public func bootstrap(
    scope: OrbitPhase1RealtimeSubscriptionScope
  ) async throws -> OrbitPhase1RealtimeSnapshot {
    guard let snapshot = try await loadSnapshot(scope) else {
      throw OrbitPhase1RealtimeFeedError.snapshotUnavailable
    }

    return snapshot
  }

  public func replay(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor
  ) async throws -> OrbitPhase1RealtimeReplayResult {
    let batch = try await loadReplayBatch(scope, cursor)

    if batch.hasGap {
      return try await resync(scope: scope, reason: .gapDetected)
    }

    if batch.events.contains(where: { $0.workspaceID != cursor.workspaceID }) {
      return try await resync(scope: scope, reason: .inconsistentReplayBatch)
    }

    let filteredEvents = OrbitPhase1RealtimeContract.events(since: cursor, in: batch.events)

    guard !filteredEvents.isEmpty else {
      return .noChange(cursor: cursor)
    }

    let nextCursor = OrbitPhase1RealtimeContract.makeReplayCursor(
      workspaceID: cursor.workspaceID,
      from: filteredEvents
    )

    return .events(filteredEvents, nextCursor: nextCursor)
  }

  public func resync(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    reason: OrbitPhase1RealtimeResyncReason
  ) async throws -> OrbitPhase1RealtimeReplayResult {
    let snapshot = try await bootstrap(scope: scope)
    return .resync(snapshot: snapshot, reason: reason)
  }

  public func validate(
    snapshot: OrbitPhase1RealtimeSnapshot,
    against cursor: OrbitPhase1ReplayCursor
  ) -> OrbitPhase1RealtimeResyncReason? {
    snapshot.room.workspace.id == cursor.workspaceID ? nil : .workspaceMismatch
  }
}
