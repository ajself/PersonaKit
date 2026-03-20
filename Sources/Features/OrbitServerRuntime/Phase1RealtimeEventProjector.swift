import Foundation

public enum OrbitPhase1RealtimeEventProjector {
  public static func bootstrapEvents(
    for room: OrbitPhase1RoomBootstrap
  ) throws -> [OrbitRealtimeEventRecord] {
    var events = [OrbitRealtimeEventRecord]()

    events.append(
      OrbitRealtimeEventRecord(
        id: room.post.id,
        workspaceID: room.workspace.id,
        postID: room.post.id,
        threadID: room.thread.id,
        category: .postCreated,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode([
          "post_id": room.post.id.uuidString,
        ]),
        createdAt: room.post.createdAt
      )
    )

    events.append(
      contentsOf: try room.postParticipants.map { participant in
        OrbitRealtimeEventRecord(
          id: participant.id,
          workspaceID: room.workspace.id,
          postID: participant.postID,
          threadID: room.thread.id,
          category: .participantJoined,
          payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
            OrbitPhase1ParticipantJoinedPayload(
              participantType: participant.participantType.rawValue,
              participantID: participant.participantID,
              joinedAt: participant.joinedAt,
              participationMode: participant.participationMode.rawValue
            )
          ),
          createdAt: participant.joinedAt
        )
      }
    )

    events.append(
      contentsOf: try room.seedMessages.map { message in
        OrbitRealtimeEventRecord(
          id: message.id,
          workspaceID: room.workspace.id,
          postID: message.postID,
          threadID: message.threadID,
          category: .messageCreated,
          payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
            OrbitPhase1MessageCreatedPayload(
              messageID: message.id,
              postID: message.postID,
              threadID: message.threadID,
              authorType: message.authorType.rawValue,
              authorID: message.authorID,
              body: message.body,
              messageFormat: message.messageFormat.rawValue,
              state: message.state.rawValue,
              createdAt: message.createdAt,
              updatedAt: message.updatedAt,
              replyToMessageID: message.replyToMessageID
            )
          ),
          createdAt: message.createdAt
        )
      }
    )

    events.append(
      OrbitRealtimeEventRecord(
        id: room.thread.id,
        workspaceID: room.workspace.id,
        postID: room.post.id,
        threadID: room.thread.id,
        category: .threadActivityUpdated,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1ThreadActivityUpdatedPayload(
            threadID: room.thread.id,
            lastActivityAt: room.thread.lastActivityAt
          )
        ),
        createdAt: room.thread.lastActivityAt
      )
    )

    events.append(
      contentsOf: try room.postEvents.compactMap { event in
        guard let category = OrbitPhase1RealtimeEventCategory(rawValue: event.eventType) else {
          return nil
        }

        return OrbitRealtimeEventRecord(
          id: event.id,
          workspaceID: room.workspace.id,
          postID: event.postID,
          threadID: event.threadID,
          category: category,
          payloadJSON: event.payloadJSON,
          createdAt: event.createdAt
        )
      }
    )

    return events.sorted { lhs, rhs in
      if lhs.createdAt == rhs.createdAt {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.createdAt < rhs.createdAt
    }
  }

  public static func appendEvents(
    workspaceID: UUID,
    message: OrbitMessageRecord,
    threadLastActivityAt: Date
  ) throws -> [OrbitRealtimeEventRecord] {
    [
      OrbitRealtimeEventRecord(
        id: message.id,
        workspaceID: workspaceID,
        postID: message.postID,
        threadID: message.threadID,
        category: .messageCreated,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1MessageCreatedPayload(
            messageID: message.id,
            postID: message.postID,
            threadID: message.threadID,
            authorType: message.authorType.rawValue,
            authorID: message.authorID,
            body: message.body,
            messageFormat: message.messageFormat.rawValue,
            state: message.state.rawValue,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            replyToMessageID: message.replyToMessageID
          )
        ),
        createdAt: message.createdAt
      ),
      OrbitRealtimeEventRecord(
        id: UUID(),
        workspaceID: workspaceID,
        postID: message.postID,
        threadID: message.threadID,
        category: .threadActivityUpdated,
        payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
          OrbitPhase1ThreadActivityUpdatedPayload(
            threadID: message.threadID,
            lastActivityAt: threadLastActivityAt
          )
        ),
        createdAt: threadLastActivityAt
      ),
    ]
  }

  public static func collaboratorResponseEvents(
    workspaceID: UUID,
    message: OrbitMessageRecord,
    eventID: UUID,
    payloadJSON: String,
    eventCreatedAt: Date,
    threadLastActivityAt: Date
  ) throws -> [OrbitRealtimeEventRecord] {
    var events = try appendEvents(
      workspaceID: workspaceID,
      message: message,
      threadLastActivityAt: threadLastActivityAt
    )

    events.append(
      OrbitRealtimeEventRecord(
        id: eventID,
        workspaceID: workspaceID,
        postID: message.postID,
        threadID: message.threadID,
        category: .activationResolved,
        payloadJSON: payloadJSON,
        createdAt: eventCreatedAt
      )
    )

    return events.sorted { lhs, rhs in
      if lhs.createdAt == rhs.createdAt {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.createdAt < rhs.createdAt
    }
  }

  public static func activationFailureEvents(
    workspaceID: UUID,
    systemMessage: OrbitMessageRecord,
    postID: UUID,
    threadID: UUID,
    eventID: UUID,
    payloadJSON: String,
    threadLastActivityAt: Date
  ) throws -> [OrbitRealtimeEventRecord] {
    var events = try appendEvents(
      workspaceID: workspaceID,
      message: systemMessage,
      threadLastActivityAt: threadLastActivityAt
    )

    events.append(
      OrbitRealtimeEventRecord(
        id: eventID,
        workspaceID: workspaceID,
        postID: postID,
        threadID: threadID,
        category: .activationFailed,
        payloadJSON: payloadJSON,
        createdAt: systemMessage.createdAt
      )
    )

    return events.sorted { lhs, rhs in
      if lhs.createdAt == rhs.createdAt {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.createdAt < rhs.createdAt
    }
  }
}
