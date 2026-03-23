import Foundation

public enum OrbitPhase1MeetingCompletionOutcome: String, Codable, Equatable, Sendable {
  case decision
  case noDecision = "no_decision"
}

public struct OrbitPhase1MeetingReferenceSpec: Codable, Equatable, Sendable {
  public let referenceType: OrbitReferenceType
  public let target: String
  public let title: String?

  public init(
    referenceType: OrbitReferenceType,
    target: String,
    title: String? = nil
  ) {
    self.referenceType = referenceType
    self.target = target
    self.title = title
  }
}

public struct OrbitPhase1CompleteMeetingRequest: Codable, Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let postID: UUID
  public let summaryBody: String
  public let outcome: OrbitPhase1MeetingCompletionOutcome
  public let decisionTitle: String?
  public let decisionBody: String?
  public let noDecisionDetail: String?
  public let openQuestions: [String]
  public let followUpReferences: [OrbitPhase1MeetingReferenceSpec]
  public let completedByParticipantType: OrbitParticipantAuthorType
  public let completedByParticipantID: String

  public init(
    workspaceSlug: String,
    channelSlug: String,
    postID: UUID,
    summaryBody: String,
    outcome: OrbitPhase1MeetingCompletionOutcome,
    decisionTitle: String? = nil,
    decisionBody: String? = nil,
    noDecisionDetail: String? = nil,
    openQuestions: [String] = [],
    followUpReferences: [OrbitPhase1MeetingReferenceSpec] = [],
    completedByParticipantType: OrbitParticipantAuthorType,
    completedByParticipantID: String
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.postID = postID
    self.summaryBody = summaryBody
    self.outcome = outcome
    self.decisionTitle = decisionTitle
    self.decisionBody = decisionBody
    self.noDecisionDetail = noDecisionDetail
    self.openQuestions = openQuestions
    self.followUpReferences = followUpReferences
    self.completedByParticipantType = completedByParticipantType
    self.completedByParticipantID = completedByParticipantID
  }
}

public struct OrbitPhase1CompleteMeetingResult: Codable, Equatable, Sendable {
  public let snapshot: OrbitPhase1RoomSnapshot
  public let summaryNote: OrbitNoteRecord
  public let meetingOutputState: OrbitMeetingOutputStateRecord
  public let decision: OrbitDecisionRecord?
  public let references: [OrbitReferenceRecord]
  public let meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord]
  public let postEvent: OrbitPostEventRecord

  public init(
    snapshot: OrbitPhase1RoomSnapshot,
    summaryNote: OrbitNoteRecord,
    meetingOutputState: OrbitMeetingOutputStateRecord,
    decision: OrbitDecisionRecord?,
    references: [OrbitReferenceRecord],
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord],
    postEvent: OrbitPostEventRecord
  ) {
    self.snapshot = snapshot
    self.summaryNote = summaryNote
    self.meetingOutputState = meetingOutputState
    self.decision = decision
    self.references = references
    self.meetingOpenQuestions = meetingOpenQuestions
    self.postEvent = postEvent
  }
}

public enum OrbitPhase1MeetingCompletionServiceError: Error, Equatable {
  case roomNotFound
  case roomIsNotMeeting
  case meetingSummaryMissing
  case meetingAlreadyCompleted
  case summaryBodyRequired
  case invalidDecisionPayload
  case invalidNoDecisionPayload
  case invalidReferencePayload
}

public struct OrbitPhase1MeetingCompletionService: Sendable {
  public typealias SnapshotLoader =
    @Sendable (String, String, UUID?) async throws -> OrbitPhase1RoomSnapshot?
  public typealias MeetingCompleter =
    @Sendable (
      UUID,
      OrbitNoteRecord,
      OrbitMeetingOutputStateRecord,
      OrbitDecisionRecord?,
      [OrbitReferenceRecord],
      [OrbitStructuredAttachmentRecord],
      [OrbitMeetingOpenQuestionRecord],
      OrbitMeetingStateRecord,
      OrbitPostEventRecord,
      [OrbitRealtimeEventRecord],
      UUID,
      Date
    ) async throws -> Void

  public let loadSnapshot: SnapshotLoader
  public let completeMeetingWrite: MeetingCompleter
  public let now: @Sendable () -> Date
  public let makeDecisionID: @Sendable () -> UUID
  public let makeReferenceID: @Sendable () -> UUID
  public let makeMeetingOpenQuestionID: @Sendable () -> UUID
  public let makePostEventID: @Sendable () -> UUID

  public init(
    loadSnapshot: @escaping SnapshotLoader,
    completeMeetingWrite: @escaping MeetingCompleter,
    now: @escaping @Sendable () -> Date = Date.init,
    makeDecisionID: @escaping @Sendable () -> UUID = UUID.init,
    makeReferenceID: @escaping @Sendable () -> UUID = UUID.init,
    makeMeetingOpenQuestionID: @escaping @Sendable () -> UUID = UUID.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadSnapshot = loadSnapshot
    self.completeMeetingWrite = completeMeetingWrite
    self.now = now
    self.makeDecisionID = makeDecisionID
    self.makeReferenceID = makeReferenceID
    self.makeMeetingOpenQuestionID = makeMeetingOpenQuestionID
    self.makePostEventID = makePostEventID
  }

  public func completeMeeting(
    _ request: OrbitPhase1CompleteMeetingRequest
  ) async throws -> OrbitPhase1CompleteMeetingResult {
    guard
      let snapshot = try await loadSnapshot(
        request.workspaceSlug,
        request.channelSlug,
        request.postID
      )
    else {
      throw OrbitPhase1MeetingCompletionServiceError.roomNotFound
    }

    guard
      snapshot.post.postType == .meeting,
      let meetingState = snapshot.meetingState
    else {
      throw OrbitPhase1MeetingCompletionServiceError.roomIsNotMeeting
    }

    guard meetingState.status != .completed else {
      throw OrbitPhase1MeetingCompletionServiceError.meetingAlreadyCompleted
    }

    guard
      let summaryNote = snapshot.notes.first(where: { $0.noteType == .meetingSummary })
    else {
      throw OrbitPhase1MeetingCompletionServiceError.meetingSummaryMissing
    }

    let trimmedSummaryBody = request.summaryBody
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedSummaryBody.isEmpty else {
      throw OrbitPhase1MeetingCompletionServiceError.summaryBodyRequired
    }

    let timestamp = now()
    let updatedSummaryNote = OrbitNoteRecord(
      id: summaryNote.id,
      postID: summaryNote.postID,
      noteType: summaryNote.noteType,
      body: trimmedSummaryBody,
      createdByParticipantType: summaryNote.createdByParticipantType,
      createdByParticipantID: summaryNote.createdByParticipantID,
      createdAt: summaryNote.createdAt
    )
    let trimmedDecisionTitle = trimmedOrNil(request.decisionTitle)
    let trimmedDecisionBody = trimmedOrNil(request.decisionBody)
    let trimmedNoDecisionDetail = trimmedOrNil(request.noDecisionDetail)
    let meetingOpenQuestions = request.openQuestions
      .compactMap(trimmedOrNil)
      .enumerated()
      .map { index, body in
        OrbitMeetingOpenQuestionRecord(
          id: makeMeetingOpenQuestionID(),
          postID: snapshot.post.id,
          body: body,
          createdByParticipantType: request.completedByParticipantType,
          createdByParticipantID: request.completedByParticipantID,
          createdAt: orderedTimestamp(
            base: timestamp,
            offset: index
          )
        )
      }
    let references = try request.followUpReferences
      .enumerated()
      .map { index, reference in
        guard let target = trimmedOrNil(reference.target) else {
          throw OrbitPhase1MeetingCompletionServiceError.invalidReferencePayload
        }

        return OrbitReferenceRecord(
          id: makeReferenceID(),
          postID: snapshot.post.id,
          referenceType: reference.referenceType,
          target: target,
          title: trimmedOrNil(reference.title),
          createdByParticipantType: request.completedByParticipantType,
          createdByParticipantID: request.completedByParticipantID,
          createdAt: orderedTimestamp(
            base: timestamp,
            offset: index + meetingOpenQuestions.count
          )
        )
      }

    let decision: OrbitDecisionRecord?
    let meetingOutputState: OrbitMeetingOutputStateRecord

    switch request.outcome {
    case .decision:
      guard
        let decisionTitle = trimmedDecisionTitle,
        let decisionBody = trimmedDecisionBody,
        trimmedNoDecisionDetail == nil
      else {
        throw OrbitPhase1MeetingCompletionServiceError.invalidDecisionPayload
      }

      decision = OrbitDecisionRecord(
        id: makeDecisionID(),
        postID: snapshot.post.id,
        title: decisionTitle,
        body: decisionBody,
        decisionState: .adopted,
        linkedReferenceIDs: references.map(\.id),
        createdByParticipantType: request.completedByParticipantType,
        createdByParticipantID: request.completedByParticipantID,
        createdAt: timestamp
      )
      meetingOutputState = OrbitMeetingOutputStateRecord(
        postID: snapshot.post.id,
        outcomeState: .decisionRecorded,
        recordedByParticipantType: request.completedByParticipantType,
        recordedByParticipantID: request.completedByParticipantID,
        recordedAt: timestamp
      )
    case .noDecision:
      guard trimmedDecisionTitle == nil, trimmedDecisionBody == nil else {
        throw OrbitPhase1MeetingCompletionServiceError.invalidNoDecisionPayload
      }

      decision = nil
      meetingOutputState = OrbitMeetingOutputStateRecord(
        postID: snapshot.post.id,
        outcomeState: .noDecisionRecorded,
        detail: trimmedNoDecisionDetail,
        recordedByParticipantType: request.completedByParticipantType,
        recordedByParticipantID: request.completedByParticipantID,
        recordedAt: timestamp
      )
    }

    let completedMeetingState = OrbitMeetingStateRecord(
      postID: meetingState.postID,
      meetingType: meetingState.meetingType,
      status: .completed,
      startedByParticipantType: meetingState.startedByParticipantType,
      startedByParticipantID: meetingState.startedByParticipantID,
      startedAt: meetingState.startedAt,
      completedAt: timestamp
    )
    let structuredAttachments = makeStructuredAttachments(
      snapshot: snapshot,
      summaryNote: updatedSummaryNote,
      decision: decision,
      references: references
    )
    let eventPayload = OrbitPhase1MeetingCompletionEventPayload(
      summaryNote: updatedSummaryNote,
      meetingOutputState: meetingOutputState,
      decision: decision,
      references: references,
      structuredAttachments: structuredAttachments,
      meetingOpenQuestions: meetingOpenQuestions,
      meetingState: completedMeetingState,
      threadLastActivityAt: timestamp
    )
    let postEvent = OrbitPostEventRecord(
      id: makePostEventID(),
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      eventType: OrbitPhase1RealtimeEventCategory.meetingOutputCommitted.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(eventPayload),
      createdAt: timestamp
    )
    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.meetingCompletionEvents(
      workspaceID: snapshot.workspace.id,
      postEvent: postEvent
    )
    do {
      try await completeMeetingWrite(
        snapshot.workspace.id,
        updatedSummaryNote,
        meetingOutputState,
        decision,
        references,
        structuredAttachments,
        meetingOpenQuestions,
        completedMeetingState,
        postEvent,
        realtimeEvents,
        snapshot.thread.id,
        timestamp
      )
    } catch let error as OrbitPostgresRuntimeStoreError {
      switch error {
      case .meetingAlreadyCompleted:
        throw OrbitPhase1MeetingCompletionServiceError.meetingAlreadyCompleted
      case .meetingStateMissing:
        throw OrbitPhase1MeetingCompletionServiceError.roomIsNotMeeting
      case .invalidEnumValue, .invalidUUIDValue:
        throw error
      }
    }

    let updatedNotes = snapshot.notes.map { note in
      note.id == updatedSummaryNote.id ? updatedSummaryNote : note
    }
    let updatedSnapshot = OrbitPhase1RoomSnapshot(
      workspace: snapshot.workspace,
      channel: snapshot.channel,
      workspacePersonas: snapshot.workspacePersonas,
      teams: snapshot.teams,
      squads: snapshot.squads,
      workspacePersonaMemberships: snapshot.workspacePersonaMemberships,
      post: snapshot.post,
      thread: OrbitThreadRecord(
        id: snapshot.thread.id,
        postID: snapshot.thread.postID,
        status: snapshot.thread.status,
        lastActivityAt: timestamp,
        createdAt: snapshot.thread.createdAt,
        closedAt: snapshot.thread.closedAt
      ),
      messages: snapshot.messages,
      postParticipants: snapshot.postParticipants,
      postLinks: snapshot.postLinks,
      notes: updatedNotes,
      decisions: snapshot.decisions + (decision.map { [$0] } ?? []),
      references: snapshot.references + references,
      artifacts: snapshot.artifacts,
      structuredAttachments: structuredAttachments,
      meetingOutputState: meetingOutputState,
      meetingOpenQuestions: snapshot.meetingOpenQuestions + meetingOpenQuestions,
      meetingState: completedMeetingState,
      meetingMembers: snapshot.meetingMembers,
      postEvents: snapshot.postEvents + [postEvent],
      personaActivations: snapshot.personaActivations,
      agentRuns: snapshot.agentRuns
    )

    return OrbitPhase1CompleteMeetingResult(
      snapshot: updatedSnapshot,
      summaryNote: updatedSummaryNote,
      meetingOutputState: meetingOutputState,
      decision: decision,
      references: references,
      meetingOpenQuestions: meetingOpenQuestions,
      postEvent: postEvent
    )
  }

  private func orderedTimestamp(
    base: Date,
    offset: Int
  ) -> Date {
    Date(timeInterval: Double(offset + 1) / 1_000, since: base)
  }

  private func makeStructuredAttachments(
    snapshot: OrbitPhase1RoomSnapshot,
    summaryNote: OrbitNoteRecord,
    decision: OrbitDecisionRecord?,
    references: [OrbitReferenceRecord]
  ) -> [OrbitStructuredAttachmentRecord] {
    let newStructuredObjectIDs = Set(
      references.map(\.id) + (decision.map { [$0.id] } ?? [])
    )
    var attachments = snapshot.structuredAttachments.filter { attachment in
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
          originPostID: snapshot.post.id,
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
          originPostID: snapshot.post.id,
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
          originPostID: snapshot.post.id,
          structuredObjectType: .reference,
          structuredObjectID: reference.id,
          attachmentOrdinal: nextOrdinal,
          attachedAt: reference.createdAt
        )
      )
      nextOrdinal += 1
    }

    return attachments.sorted { lhs, rhs in
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

  private func trimmedOrNil(
    _ value: String?
  ) -> String? {
    guard let value else {
      return nil
    }

    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedValue.isEmpty ? nil : trimmedValue
  }
}

public protocol OrbitPhase1MeetingCompletionServing: Sendable {
  func completeMeeting(
    _ request: OrbitPhase1CompleteMeetingRequest
  ) async throws -> OrbitPhase1CompleteMeetingResult
}

extension OrbitPhase1MeetingCompletionService {
  public init(
    runtimeStore: OrbitPostgresRuntimeStore,
    now: @escaping @Sendable () -> Date = Date.init,
    makeDecisionID: @escaping @Sendable () -> UUID = UUID.init,
    makeReferenceID: @escaping @Sendable () -> UUID = UUID.init,
    makeMeetingOpenQuestionID: @escaping @Sendable () -> UUID = UUID.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.init(
      loadSnapshot: { workspaceSlug, channelSlug, postID in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug,
          postID: postID
        )
      },
      completeMeetingWrite: {
        workspaceID,
        summaryNote,
        meetingOutputState,
        decision,
        references,
        structuredAttachments,
        meetingOpenQuestions,
        meetingState,
        postEvent,
        realtimeEvents,
        threadID,
        threadLastActivityAt in
        do {
          try await runtimeStore.completeMeeting(
            workspaceID: workspaceID,
            summaryNote: summaryNote,
            meetingOutputState: meetingOutputState,
            decision: decision,
            references: references,
            structuredAttachments: structuredAttachments,
            meetingOpenQuestions: meetingOpenQuestions,
            meetingState: meetingState,
            postEvent: postEvent,
            realtimeEvents: realtimeEvents,
            threadID: threadID,
            threadLastActivityAt: threadLastActivityAt
          )
        } catch let error as OrbitPostgresRuntimeStoreError {
          switch error {
          case .meetingAlreadyCompleted:
            throw OrbitPhase1MeetingCompletionServiceError.meetingAlreadyCompleted
          case .meetingStateMissing:
            throw OrbitPhase1MeetingCompletionServiceError.roomIsNotMeeting
          case .invalidEnumValue, .invalidUUIDValue:
            throw error
          }
        }
      },
      now: now,
      makeDecisionID: makeDecisionID,
      makeReferenceID: makeReferenceID,
      makeMeetingOpenQuestionID: makeMeetingOpenQuestionID,
      makePostEventID: makePostEventID
    )
  }
}

extension OrbitPhase1MeetingCompletionService: OrbitPhase1MeetingCompletionServing {}
