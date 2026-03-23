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
            postLinks: room.postLinks,
            notes: room.notes,
            decisions: room.decisions,
            references: room.references,
            artifacts: room.artifacts,
            structuredAttachments: room.structuredAttachments,
            meetingOutputState: room.meetingOutputState,
            meetingOpenQuestions: room.meetingOpenQuestions,
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
            postLinks: room.postLinks,
            notes: room.notes,
            decisions: room.decisions,
            references: room.references,
            artifacts: room.artifacts,
            structuredAttachments: room.structuredAttachments,
            meetingOutputState: room.meetingOutputState,
            meetingOpenQuestions: room.meetingOpenQuestions,
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
          postLinks: room.postLinks,
          notes: room.notes,
          decisions: room.decisions,
          references: room.references,
          artifacts: room.artifacts,
          structuredAttachments: room.structuredAttachments,
          meetingOutputState: room.meetingOutputState,
          meetingOpenQuestions: room.meetingOpenQuestions,
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
          postLinks: room.postLinks,
          notes: room.notes,
          decisions: room.decisions,
          references: room.references,
          artifacts: room.artifacts,
          structuredAttachments: room.structuredAttachments,
          meetingOutputState: room.meetingOutputState,
          meetingOpenQuestions: room.meetingOpenQuestions,
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
            postLinks: room.postLinks,
            notes: room.notes,
            decisions: room.decisions,
            references: room.references,
            artifacts: room.artifacts,
            structuredAttachments: room.structuredAttachments,
            meetingOutputState: room.meetingOutputState,
            meetingOpenQuestions: room.meetingOpenQuestions,
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
            postLinks: room.postLinks,
            notes: room.notes,
            decisions: room.decisions,
            references: room.references,
            artifacts: room.artifacts,
            structuredAttachments: room.structuredAttachments,
            meetingOutputState: room.meetingOutputState,
            meetingOpenQuestions: room.meetingOpenQuestions,
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
      case .meetingOutputCommitted:
        let payload = try OrbitPhase1RealtimeEventPayloadCodec.decode(
          OrbitPhase1MeetingCompletionEventPayload.self,
          from: event.payloadJSON
        )
        let notes = mergeNotes(
          room.notes,
          note: payload.summaryNote
        )
        let decisions = mergeDecisions(
          room.decisions,
          decision: payload.decision
        )
        let references = mergeReferences(
          room.references,
          references: payload.references
        )
        let meetingOpenQuestions = mergeMeetingOpenQuestions(
          room.meetingOpenQuestions,
          questions: payload.meetingOpenQuestions
        )
        let structuredAttachments: [OrbitStructuredAttachmentRecord]? =
          payload.structuredAttachments.isEmpty
          ? mergeStructuredAttachments(
              room.structuredAttachments,
              postID: room.post.id,
              summaryNote: payload.summaryNote,
              decision: payload.decision,
              references: payload.references
            )
          : payload.structuredAttachments
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
            lastActivityAt: payload.threadLastActivityAt,
            createdAt: room.thread.createdAt,
            closedAt: room.thread.closedAt
          ),
          messages: room.messages,
          postParticipants: room.postParticipants,
          postLinks: room.postLinks,
          notes: notes,
          decisions: decisions,
          references: references,
          artifacts: room.artifacts,
          structuredAttachments: structuredAttachments,
          meetingOutputState: payload.meetingOutputState,
          meetingOpenQuestions: meetingOpenQuestions,
          meetingState: payload.meetingState,
          meetingMembers: room.meetingMembers,
          postEvents: postEvents,
          personaActivations: room.personaActivations,
          agentRuns: room.agentRuns
        )
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

  private static func mergeNotes(
    _ current: [OrbitNoteRecord],
    note: OrbitNoteRecord
  ) -> [OrbitNoteRecord] {
    let merged = current.contains(where: { $0.id == note.id })
      ? current.map { existingNote in
          existingNote.id == note.id ? note : existingNote
        }
      : current + [note]

    return merged.sorted(by: noteSort)
  }

  private static func mergeDecisions(
    _ current: [OrbitDecisionRecord],
    decision: OrbitDecisionRecord?
  ) -> [OrbitDecisionRecord] {
    guard let decision else {
      return current.sorted(by: decisionSort)
    }

    let merged = current.contains(where: { $0.id == decision.id })
      ? current
      : current + [decision]

    return merged.sorted(by: decisionSort)
  }

  private static func mergeReferences(
    _ current: [OrbitReferenceRecord],
    references: [OrbitReferenceRecord]
  ) -> [OrbitReferenceRecord] {
    var merged = current

    for reference in references where !merged.contains(where: { $0.id == reference.id }) {
      merged.append(reference)
    }

    return merged.sorted(by: referenceSort)
  }

  private static func mergeMeetingOpenQuestions(
    _ current: [OrbitMeetingOpenQuestionRecord],
    questions: [OrbitMeetingOpenQuestionRecord]
  ) -> [OrbitMeetingOpenQuestionRecord] {
    var merged = current

    for question in questions where !merged.contains(where: { $0.id == question.id }) {
      merged.append(question)
    }

    return merged.sorted(by: meetingOpenQuestionSort)
  }

  private static func mergeStructuredAttachments(
    _ current: [OrbitStructuredAttachmentRecord],
    postID: UUID,
    summaryNote: OrbitNoteRecord,
    decision: OrbitDecisionRecord?,
    references: [OrbitReferenceRecord]
  ) -> [OrbitStructuredAttachmentRecord] {
    let newStructuredObjectIDs = Set(
      references.map(\.id) + (decision.map { [$0.id] } ?? [])
    )
    var attachments = current.filter { attachment in
      !newStructuredObjectIDs.contains(attachment.structuredObjectID)
    }

    if attachments.contains(where: {
      $0.structuredObjectType == .note && $0.structuredObjectID == summaryNote.id
    }) == false {
      let summaryOrdinal = attachments.isEmpty
        ? 0
        : (attachments.map(\.attachmentOrdinal).max() ?? -1) + 1

      attachments.append(
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .note,
          structuredObjectID: summaryNote.id,
          attachmentOrdinal: summaryOrdinal,
          attachedAt: summaryNote.createdAt
        )
      )
    }

    var nextOrdinal = (attachments.map(\.attachmentOrdinal).max() ?? -1) + 1

    if let decision {
      attachments.append(
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .decision,
          structuredObjectID: decision.id,
          attachmentOrdinal: nextOrdinal,
          attachedAt: decision.createdAt
        )
      )
      nextOrdinal += 1
    }

    for reference in references {
      attachments.append(
        OrbitStructuredAttachmentRecord(
          originPostID: postID,
          structuredObjectType: .reference,
          structuredObjectID: reference.id,
          attachmentOrdinal: nextOrdinal,
          attachedAt: reference.createdAt
        )
      )
      nextOrdinal += 1
    }

    return attachments.sorted(by: structuredAttachmentSort)
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

  private static func noteSort(
    _ lhs: OrbitNoteRecord,
    _ rhs: OrbitNoteRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }

  private static func decisionSort(
    _ lhs: OrbitDecisionRecord,
    _ rhs: OrbitDecisionRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }

  private static func referenceSort(
    _ lhs: OrbitReferenceRecord,
    _ rhs: OrbitReferenceRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }

  private static func meetingOpenQuestionSort(
    _ lhs: OrbitMeetingOpenQuestionRecord,
    _ rhs: OrbitMeetingOpenQuestionRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }

  private static func structuredAttachmentSort(
    _ lhs: OrbitStructuredAttachmentRecord,
    _ rhs: OrbitStructuredAttachmentRecord
  ) -> Bool {
    if lhs.attachmentOrdinal == rhs.attachmentOrdinal {
      if lhs.attachedAt == rhs.attachedAt {
        if lhs.structuredObjectType == rhs.structuredObjectType {
          return lhs.structuredObjectID.uuidString < rhs.structuredObjectID.uuidString
        }

        return lhs.structuredObjectType.rawValue < rhs.structuredObjectType.rawValue
      }

      return lhs.attachedAt < rhs.attachedAt
    }

    return lhs.attachmentOrdinal < rhs.attachmentOrdinal
  }
}
