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
      channelSlug: scope.channelSlug
    ) else {
      return nil
    }

    let events = realtimeEvents(for: room)
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
    guard let room = try await runtimeStore.loadRoomSnapshot(
      workspaceSlug: scope.workspaceSlug,
      channelSlug: scope.channelSlug
    ) else {
      return OrbitPhase1RealtimeReplayBatch(events: [], hasGap: false)
    }

    let events = realtimeEvents(for: room)
    let replayEvents = OrbitPhase1RealtimeContract.events(since: cursor, in: events)

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

  public func realtimeEvents(
    for room: OrbitPhase1RoomSnapshot
  ) -> [OrbitPhase1RealtimeEventEnvelope] {
    var events = [OrbitPhase1RealtimeEventEnvelope]()

    events.append(
      OrbitPhase1RealtimeEventEnvelope(
        id: room.post.id,
        workspaceID: room.workspace.id,
        postID: room.post.id,
        threadID: room.thread.id,
        category: .postCreated,
        createdAt: room.post.createdAt,
        payloadJSON: "{\"post_id\":\"\(room.post.id.uuidString)\"}"
      )
    )

    for participant in room.postParticipants {
      events.append(
        OrbitPhase1RealtimeEventEnvelope(
          id: participant.id,
          workspaceID: room.workspace.id,
          postID: room.post.id,
          threadID: room.thread.id,
          category: .participantJoined,
          createdAt: participant.joinedAt,
          payloadJSON: "{\"participant_id\":\"\(participant.participantID)\",\"mode\":\"\(participant.participationMode.rawValue)\"}"
        )
      )
    }

    for message in room.messages {
      events.append(
        OrbitPhase1RealtimeEventEnvelope(
          id: message.id,
          workspaceID: room.workspace.id,
          postID: room.post.id,
          threadID: room.thread.id,
          category: .messageCreated,
          createdAt: message.createdAt,
          payloadJSON: "{\"message_id\":\"\(message.id.uuidString)\",\"author_id\":\"\(message.authorID)\"}"
        )
      )
    }

    events.append(
      OrbitPhase1RealtimeEventEnvelope(
        id: room.thread.id,
        workspaceID: room.workspace.id,
        postID: room.post.id,
        threadID: room.thread.id,
        category: .threadActivityUpdated,
        createdAt: room.thread.lastActivityAt,
        payloadJSON: "{\"thread_id\":\"\(room.thread.id.uuidString)\"}"
      )
    )

    for event in room.postEvents {
      if let category = OrbitPhase1RealtimeEventCategory(rawValue: event.eventType) {
        events.append(
          OrbitPhase1RealtimeEventEnvelope(
            id: event.id,
            workspaceID: room.workspace.id,
            postID: event.postID,
            threadID: event.threadID,
            category: category,
            createdAt: event.createdAt,
            payloadJSON: event.payloadJSON
          )
        )
      }
    }

    return events.sorted { lhs, rhs in
      if lhs.createdAt == rhs.createdAt {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.createdAt < rhs.createdAt
    }
  }
}
