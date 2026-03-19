import Foundation

public enum OrbitPhase1RealtimeSnapshotReducerError: Error, Equatable {
  case invalidEnumValue(column: String, rawValue: String)
}

public enum OrbitPhase1RealtimeSnapshotReducer {
  public static func applying(
    events: [OrbitPhase1RealtimeEventEnvelope],
    to snapshot: OrbitPhase1RealtimeSnapshot
  ) throws -> OrbitPhase1RealtimeSnapshot {
    var room = snapshot.room

    for event in OrbitPhase1RealtimeContract.events(since: snapshot.replayCursor, in: events) {
      switch event.category {
      case .participantJoined:
        let payload = try OrbitPhase1RealtimeEventPayloadCodec.decode(
          OrbitPhase1ParticipantJoinedPayload.self,
          from: event.payloadJSON
        )

        if !room.postParticipants.contains(where: { $0.id == event.id }) {
          room = OrbitPhase1RoomSnapshot(
            workspace: room.workspace,
            channel: room.channel,
            workspacePersonas: room.workspacePersonas,
            post: room.post,
            thread: room.thread,
            messages: room.messages,
            postParticipants: room.postParticipants + [
              OrbitPostParticipantRecord(
                id: event.id,
                postID: event.postID ?? room.post.id,
                participantType: try decodeEnum(
                  OrbitParticipantAuthorType.self,
                  from: payload.participantType,
                  columnName: "participantType"
                ),
                participantID: payload.participantID,
                joinedAt: payload.joinedAt,
                participationMode: try decodeEnum(
                  OrbitParticipationMode.self,
                  from: payload.participationMode,
                  columnName: "participationMode"
                )
              )
            ],
            postEvents: room.postEvents,
            personaActivations: room.personaActivations,
            agentRuns: room.agentRuns
          )
        }
      case .messageCreated:
        let payload = try OrbitPhase1RealtimeEventPayloadCodec.decode(
          OrbitPhase1MessageCreatedPayload.self,
          from: event.payloadJSON
        )

        if !room.messages.contains(where: { $0.id == payload.messageID }) {
          var messages = room.messages
          messages.append(
            OrbitMessageRecord(
              id: payload.messageID,
              postID: payload.postID,
              threadID: payload.threadID,
              authorType: try decodeEnum(
                OrbitParticipantAuthorType.self,
                from: payload.authorType,
                columnName: "authorType"
              ),
              authorID: payload.authorID,
              replyToMessageID: payload.replyToMessageID,
              body: payload.body,
              messageFormat: try decodeEnum(
                OrbitMessageFormat.self,
                from: payload.messageFormat,
                columnName: "messageFormat"
              ),
              state: try decodeEnum(
                OrbitMessageState.self,
                from: payload.state,
                columnName: "state"
              ),
              createdAt: payload.createdAt,
              updatedAt: payload.updatedAt
            )
          )
          messages.sort { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
              return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
          }

          room = OrbitPhase1RoomSnapshot(
            workspace: room.workspace,
            channel: room.channel,
            workspacePersonas: room.workspacePersonas,
            post: room.post,
            thread: room.thread,
            messages: messages,
            postParticipants: room.postParticipants,
            postEvents: room.postEvents,
            personaActivations: room.personaActivations,
            agentRuns: room.agentRuns
          )
        }
      case .threadActivityUpdated:
        let payload = try OrbitPhase1RealtimeEventPayloadCodec.decode(
          OrbitPhase1ThreadActivityUpdatedPayload.self,
          from: event.payloadJSON
        )

        room = OrbitPhase1RoomSnapshot(
          workspace: room.workspace,
          channel: room.channel,
          workspacePersonas: room.workspacePersonas,
          post: room.post,
          thread: OrbitThreadRecord(
            id: room.thread.id,
            postID: room.thread.postID,
            status: room.thread.status,
            lastActivityAt: payload.lastActivityAt,
            createdAt: room.thread.createdAt,
            closedAt: room.thread.closedAt
          ),
          messages: room.messages,
          postParticipants: room.postParticipants,
          postEvents: room.postEvents,
          personaActivations: room.personaActivations,
          agentRuns: room.agentRuns
        )
      case .activationResolved, .activationFailed:
        if !room.postEvents.contains(where: { $0.id == event.id }) {
          room = OrbitPhase1RoomSnapshot(
            workspace: room.workspace,
            channel: room.channel,
            workspacePersonas: room.workspacePersonas,
            post: room.post,
            thread: room.thread,
            messages: room.messages,
            postParticipants: room.postParticipants,
            postEvents: room.postEvents + [
              OrbitPostEventRecord(
                id: event.id,
                postID: event.postID ?? room.post.id,
                threadID: event.threadID,
                eventType: event.category.rawValue,
                payloadJSON: event.payloadJSON,
                createdAt: event.createdAt
              )
            ],
            personaActivations: room.personaActivations,
            agentRuns: room.agentRuns
          )
        }
      case .postCreated, .participantFailed:
        continue
      }
    }

    let nextCursor = events.isEmpty
      ? snapshot.replayCursor
      : OrbitPhase1RealtimeContract.makeReplayCursor(
          workspaceID: snapshot.room.workspace.id,
          from: events
        )

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: nextCursor
    )
  }

  private static func decodeEnum<Value: RawRepresentable>(
    _ type: Value.Type,
    from rawValue: String,
    columnName: String
  ) throws -> Value where Value.RawValue == String {
    guard let value = Value(rawValue: rawValue) else {
      throw OrbitPhase1RealtimeSnapshotReducerError.invalidEnumValue(
        column: columnName,
        rawValue: rawValue
      )
    }

    return value
  }
}
