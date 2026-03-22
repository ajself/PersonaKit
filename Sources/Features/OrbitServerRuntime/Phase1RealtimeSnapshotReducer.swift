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
            teams: room.teams,
            squads: room.squads,
            workspacePersonaMemberships: room.workspacePersonaMemberships,
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
            meetingState: room.meetingState,
            meetingMembers: room.meetingMembers,
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
            teams: room.teams,
            squads: room.squads,
            workspacePersonaMemberships: room.workspacePersonaMemberships,
            post: room.post,
            thread: room.thread,
            messages: messages,
            postParticipants: room.postParticipants,
            meetingState: room.meetingState,
            meetingMembers: room.meetingMembers,
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
          teams: room.teams,
          squads: room.squads,
          workspacePersonaMemberships: room.workspacePersonaMemberships,
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
          meetingState: room.meetingState,
          meetingMembers: room.meetingMembers,
          postEvents: room.postEvents,
          personaActivations: room.personaActivations,
          agentRuns: room.agentRuns
        )
      case .activationResolved:
        let payload = try OrbitPhase1RealtimeEventPayloadCodec.decode(
          OrbitPhase1ActivationEventPayload.self,
          from: event.payloadJSON
        )

        let postEvents = room.postEvents.contains(where: { $0.id == event.id })
          ? room.postEvents
          : room.postEvents + [
              OrbitPostEventRecord(
                id: event.id,
                postID: event.postID ?? room.post.id,
                threadID: event.threadID,
                eventType: event.category.rawValue,
                payloadJSON: event.payloadJSON,
                createdAt: event.createdAt
              )
            ]
        let personaActivations = try mergedPersonaActivations(
          room.personaActivations,
          payload: payload,
          event: event,
          room: room
        )
        let agentRuns = try mergedAgentRuns(
          room.agentRuns,
          payload: payload
        )

        room = OrbitPhase1RoomSnapshot(
          workspace: room.workspace,
          channel: room.channel,
          workspacePersonas: room.workspacePersonas,
          teams: room.teams,
          squads: room.squads,
          workspacePersonaMemberships: room.workspacePersonaMemberships,
          post: room.post,
          thread: room.thread,
          messages: room.messages,
          postParticipants: room.postParticipants,
          meetingState: room.meetingState,
          meetingMembers: room.meetingMembers,
          postEvents: postEvents,
          personaActivations: personaActivations,
          agentRuns: agentRuns
        )
      case .activationFailed:
        if !room.postEvents.contains(where: { $0.id == event.id }) {
          room = OrbitPhase1RoomSnapshot(
            workspace: room.workspace,
            channel: room.channel,
            workspacePersonas: room.workspacePersonas,
            teams: room.teams,
            squads: room.squads,
            workspacePersonaMemberships: room.workspacePersonaMemberships,
            post: room.post,
            thread: room.thread,
            messages: room.messages,
            postParticipants: room.postParticipants,
            meetingState: room.meetingState,
            meetingMembers: room.meetingMembers,
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
      case .meetingPromotionAttempted, .meetingPromotionFailed:
        if !room.postEvents.contains(where: { $0.id == event.id }) {
          room = OrbitPhase1RoomSnapshot(
            workspace: room.workspace,
            channel: room.channel,
            workspacePersonas: room.workspacePersonas,
            teams: room.teams,
            squads: room.squads,
            workspacePersonaMemberships: room.workspacePersonaMemberships,
            post: room.post,
            thread: room.thread,
            messages: room.messages,
            postParticipants: room.postParticipants,
            meetingState: room.meetingState,
            meetingMembers: room.meetingMembers,
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

  private static func mergedPersonaActivations(
    _ current: [OrbitPersonaActivationRecord],
    payload: OrbitPhase1ActivationEventPayload,
    event: OrbitPhase1RealtimeEventEnvelope,
    room: OrbitPhase1RoomSnapshot
  ) throws -> [OrbitPersonaActivationRecord] {
    guard
      let activationID = payload.activationID,
      !current.contains(where: { $0.id == activationID }),
      let initiatedByParticipantTypeRawValue = payload.initiatedByParticipantType,
      let initiatedByParticipantID = payload.initiatedByParticipantID,
      let triggerMessageID = payload.triggerMessageID,
      let addressedTargetKindRawValue = payload.addressedTargetKind,
      let addressedTargetReferenceID = payload.addressedTargetReferenceID,
      let resolvedWorkspacePersonaInstanceID = payload.resolvedWorkspacePersonaInstanceID,
      let responseModeRawValue = payload.responseMode
    else {
      return current
    }

    return current + [
      OrbitPersonaActivationRecord(
        id: activationID,
        initiatedByParticipantType: try decodeEnum(
          OrbitParticipantAuthorType.self,
          from: initiatedByParticipantTypeRawValue,
          columnName: "initiatedByParticipantType"
        ),
        initiatedByParticipantID: initiatedByParticipantID,
        workspaceID: event.workspaceID,
        channelID: room.channel.id,
        originPostID: event.postID ?? room.post.id,
        originThreadID: event.threadID ?? room.thread.id,
        triggerMessageID: triggerMessageID,
        addressedTargetKind: try decodeEnum(
          OrbitAddressedTargetKind.self,
          from: addressedTargetKindRawValue,
          columnName: "addressedTargetKind"
        ),
        addressedTargetReferenceID: addressedTargetReferenceID,
        resolvedWorkspacePersonaInstanceID: resolvedWorkspacePersonaInstanceID,
        responseMode: try decodeEnum(
          OrbitCanonicalResponseMode.self,
          from: responseModeRawValue,
          columnName: "responseMode"
        ),
        createdAt: event.createdAt
      )
    ]
  }

  private static func mergedAgentRuns(
    _ current: [OrbitAgentRunRecord],
    payload: OrbitPhase1ActivationEventPayload
  ) throws -> [OrbitAgentRunRecord] {
    guard
      let agentRunID = payload.agentRunID,
      !current.contains(where: { $0.id == agentRunID }),
      let activationID = payload.activationID,
      let runnerKind = payload.runnerKind,
      let agentRunStatusRawValue = payload.agentRunStatus,
      let agentRunStartedAt = payload.agentRunStartedAt
    else {
      return current
    }

    return current + [
      OrbitAgentRunRecord(
        id: agentRunID,
        personaActivationID: activationID,
        runnerKind: runnerKind,
        status: try decodeEnum(
          OrbitAgentRunStatus.self,
          from: agentRunStatusRawValue,
          columnName: "agentRunStatus"
        ),
        startedAt: agentRunStartedAt,
        completedAt: payload.agentRunCompletedAt,
        failureReason: payload.reason
      )
    ]
  }
}
