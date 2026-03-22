import Foundation

public struct OrbitPhase1ReplayCursor: Codable, Equatable, Sendable {
  public let workspaceID: UUID
  public let lastEventID: UUID?
  public let lastEventCreatedAt: Date?

  public init(
    workspaceID: UUID,
    lastEventID: UUID? = nil,
    lastEventCreatedAt: Date? = nil
  ) {
    self.workspaceID = workspaceID
    self.lastEventID = lastEventID
    self.lastEventCreatedAt = lastEventCreatedAt
  }
}

public enum OrbitPhase1RealtimeEventCategory: String, CaseIterable, Codable, Sendable {
  case postCreated = "post.created"
  case messageCreated = "message.created"
  case threadActivityUpdated = "thread.activity.updated"
  case participantJoined = "participant.joined"
  case participantFailed = "participant.failed"
  case activationResolved = "activation.resolved"
  case activationFailed = "activation.failed"
  case meetingPromotionAttempted = "meeting.promotion.attempted"
  case meetingPromotionFailed = "meeting.promotion.failed"
  case meetingOutputCommitted = "meeting.output.committed"
}

public struct OrbitPhase1RealtimeEventEnvelope: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let postID: UUID?
  public let threadID: UUID?
  public let category: OrbitPhase1RealtimeEventCategory
  public let createdAt: Date
  public let payloadJSON: String

  public init(
    id: UUID,
    workspaceID: UUID,
    postID: UUID? = nil,
    threadID: UUID? = nil,
    category: OrbitPhase1RealtimeEventCategory,
    createdAt: Date,
    payloadJSON: String
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.postID = postID
    self.threadID = threadID
    self.category = category
    self.createdAt = createdAt
    self.payloadJSON = payloadJSON
  }
}

public struct OrbitPhase1RealtimeSnapshot: Codable, Equatable, Sendable {
  public let room: OrbitPhase1RoomSnapshot
  public let replayCursor: OrbitPhase1ReplayCursor

  public init(
    room: OrbitPhase1RoomSnapshot,
    replayCursor: OrbitPhase1ReplayCursor
  ) {
    self.room = room
    self.replayCursor = replayCursor
  }
}

public enum OrbitPhase1RealtimeContract {
  public static var categories: [String] {
    OrbitPhase1RealtimeEventCategory.allCases.map { $0.rawValue }
  }

  public static func makeReplayCursor(
    workspaceID: UUID,
    from events: [OrbitPhase1RealtimeEventEnvelope]
  ) -> OrbitPhase1ReplayCursor {
    let latestEvent = events.max { lhs, rhs in
      if lhs.createdAt == rhs.createdAt {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.createdAt < rhs.createdAt
    }

    return OrbitPhase1ReplayCursor(
      workspaceID: workspaceID,
      lastEventID: latestEvent?.id,
      lastEventCreatedAt: latestEvent?.createdAt
    )
  }

  public static func events(
    since cursor: OrbitPhase1ReplayCursor,
    in events: [OrbitPhase1RealtimeEventEnvelope]
  ) -> [OrbitPhase1RealtimeEventEnvelope] {
    events
      .filter { event in
        guard let lastEventCreatedAt = cursor.lastEventCreatedAt else {
          return true
        }

        if event.createdAt > lastEventCreatedAt {
          return true
        }

        if event.createdAt == lastEventCreatedAt,
          let lastEventID = cursor.lastEventID
        {
          return event.id.uuidString > lastEventID.uuidString
        }

        return false
      }
      .sorted { lhs, rhs in
        if lhs.createdAt == rhs.createdAt {
          return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.createdAt < rhs.createdAt
      }
  }
}
