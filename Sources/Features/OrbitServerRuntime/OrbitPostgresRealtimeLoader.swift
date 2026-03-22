import Foundation
import PostgresNIO

public struct OrbitPostgresRealtimeLoader: Sendable {
  public let runtimeStore: OrbitPostgresRuntimeStore

  public init(
    runtimeStore: OrbitPostgresRuntimeStore
  ) {
    self.runtimeStore = runtimeStore
  }

  public func loadSnapshot(
    scope: OrbitPhase1RealtimeSubscriptionScope
  ) async throws -> OrbitPhase1RealtimeSnapshot? {
    guard let room = try await runtimeStore.loadRoomSnapshot(
      workspaceSlug: scope.workspaceSlug,
      channelSlug: scope.channelSlug,
      postID: scope.postID
    ) else {
      return nil
    }

    let events = try await runtimeStore.loadRealtimeEvents(
      workspaceID: room.workspace.id,
      postID: scope.postID,
      after: nil
    )
    let cursor = OrbitPhase1RealtimeContract.makeReplayCursor(
      workspaceID: room.workspace.id,
      from: events
    )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: cursor
    )
  }

  public func loadReplayBatch(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor
  ) async throws -> OrbitPhase1RealtimeReplayBatch {
    guard try await runtimeStore.loadRoomSnapshot(
      workspaceSlug: scope.workspaceSlug,
      channelSlug: scope.channelSlug,
      postID: scope.postID
    ) != nil else {
      return OrbitPhase1RealtimeReplayBatch(events: [], hasGap: false)
    }

    let replayEvents = try await runtimeStore.loadRealtimeEvents(
      workspaceID: cursor.workspaceID,
      postID: scope.postID,
      after: cursor
    )

    return OrbitPhase1RealtimeReplayBatch(events: replayEvents)
  }

  public func makeFeedService() -> OrbitPhase1RealtimeFeedService {
    OrbitPhase1RealtimeFeedService(
      loadSnapshot: { scope in
        try await loadSnapshot(scope: scope)
      },
      loadReplayBatch: { scope, cursor in
        try await loadReplayBatch(scope: scope, cursor: cursor)
      }
    )
  }

}
