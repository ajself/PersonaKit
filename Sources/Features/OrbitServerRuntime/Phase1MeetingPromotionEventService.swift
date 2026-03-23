import Foundation

public struct OrbitPhase1AppendMeetingPromotionEventRequest: Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let postID: UUID?
  public let promotion: OrbitPhase1MeetingPromotionEventPayload

  public init(
    workspaceSlug: String,
    channelSlug: String,
    postID: UUID? = nil,
    promotion: OrbitPhase1MeetingPromotionEventPayload
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.postID = postID
    self.promotion = promotion
  }
}

public struct OrbitPhase1AppendMeetingPromotionEventResult: Codable, Equatable, Sendable {
  public let snapshot: OrbitPhase1RoomSnapshot
  public let postEvent: OrbitPostEventRecord
  public let systemMessage: OrbitMessageRecord?

  public init(
    snapshot: OrbitPhase1RoomSnapshot,
    postEvent: OrbitPostEventRecord,
    systemMessage: OrbitMessageRecord? = nil
  ) {
    self.snapshot = snapshot
    self.postEvent = postEvent
    self.systemMessage = systemMessage
  }
}

public enum OrbitPhase1MeetingPromotionEventServiceError: Error, Equatable {
  case roomNotFound
}

public struct OrbitPhase1MeetingPromotionEventService: Sendable {
  public typealias SnapshotLoader =
    @Sendable (String, String, UUID?) async throws -> OrbitPhase1RoomSnapshot?
  public typealias PostEventAppender =
    @Sendable (
      UUID,
      OrbitPostEventRecord,
      [OrbitRealtimeEventRecord]
    ) async throws -> Void
  public typealias FailureAppender =
    @Sendable (
      UUID,
      OrbitMessageRecord,
      OrbitPostEventRecord,
      [OrbitRealtimeEventRecord],
      OrbitMeetingStateRecord?,
      Date
    ) async throws -> Void

  public let loadSnapshot: SnapshotLoader
  public let appendPostEvent: PostEventAppender
  public let appendFailure: FailureAppender
  public let now: @Sendable () -> Date
  public let makePostEventID: @Sendable () -> UUID

  public init(
    loadSnapshot: @escaping SnapshotLoader,
    appendPostEvent: @escaping PostEventAppender,
    appendFailure: @escaping FailureAppender,
    now: @escaping @Sendable () -> Date = Date.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadSnapshot = loadSnapshot
    self.appendPostEvent = appendPostEvent
    self.appendFailure = appendFailure
    self.now = now
    self.makePostEventID = makePostEventID
  }

  public func appendMeetingPromotionEvent(
    _ request: OrbitPhase1AppendMeetingPromotionEventRequest
  ) async throws -> OrbitPhase1AppendMeetingPromotionEventResult {
    guard let snapshot = try await loadSnapshot(
      request.workspaceSlug,
      request.channelSlug,
      request.postID
    ) else {
      throw OrbitPhase1MeetingPromotionEventServiceError.roomNotFound
    }

    let timestamp = now()
    let eventCategory: OrbitPhase1RealtimeEventCategory =
      request.promotion.failure == nil
      ? .meetingPromotionAttempted
      : .meetingPromotionFailed
    let postEvent = OrbitPostEventRecord(
      id: makePostEventID(),
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      eventType: eventCategory.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(request.promotion),
      createdAt: timestamp
    )

    if let failure = request.promotion.failure {
      let systemMessage = OrbitMessageRecord(
        id: failure.systemEventMessageID,
        postID: snapshot.post.id,
        threadID: snapshot.thread.id,
        authorType: .system,
        authorID: "orbit-system",
        body: failure.systemEventBody,
        messageFormat: .plainText,
        state: .completed,
        createdAt: timestamp,
        updatedAt: timestamp
      )
      let realtimeEvents = try OrbitPhase1RealtimeEventProjector.meetingPromotionFailureEvents(
        workspaceID: snapshot.workspace.id,
        systemMessage: systemMessage,
        postEvent: postEvent,
        threadLastActivityAt: timestamp
      )

      try await appendFailure(
        snapshot.workspace.id,
        systemMessage,
        postEvent,
        realtimeEvents,
        snapshot.meetingState,
        timestamp
      )

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
        messages: snapshot.messages + [systemMessage],
        postParticipants: snapshot.postParticipants,
        postLinks: snapshot.postLinks,
        notes: snapshot.notes,
        decisions: snapshot.decisions,
        references: snapshot.references,
        artifacts: snapshot.artifacts,
        structuredAttachments: snapshot.structuredAttachments,
        meetingOutputState: snapshot.meetingOutputState,
        meetingOpenQuestions: snapshot.meetingOpenQuestions,
        meetingState: snapshot.meetingState,
        meetingMembers: snapshot.meetingMembers,
        postEvents: snapshot.postEvents + [postEvent],
        personaActivations: snapshot.personaActivations,
        agentRuns: snapshot.agentRuns
      )

      return OrbitPhase1AppendMeetingPromotionEventResult(
        snapshot: updatedSnapshot,
        postEvent: postEvent,
        systemMessage: systemMessage
      )
    }

    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.postEventOnlyEvents(
      workspaceID: snapshot.workspace.id,
      postEvent: postEvent
    )

    try await appendPostEvent(
      snapshot.workspace.id,
      postEvent,
      realtimeEvents
    )

    let updatedSnapshot = OrbitPhase1RoomSnapshot(
      workspace: snapshot.workspace,
      channel: snapshot.channel,
      workspacePersonas: snapshot.workspacePersonas,
      teams: snapshot.teams,
      squads: snapshot.squads,
      workspacePersonaMemberships: snapshot.workspacePersonaMemberships,
      post: snapshot.post,
      thread: snapshot.thread,
      messages: snapshot.messages,
      postParticipants: snapshot.postParticipants,
      postLinks: snapshot.postLinks,
      notes: snapshot.notes,
      decisions: snapshot.decisions,
      references: snapshot.references,
      artifacts: snapshot.artifacts,
      structuredAttachments: snapshot.structuredAttachments,
      meetingOutputState: snapshot.meetingOutputState,
      meetingOpenQuestions: snapshot.meetingOpenQuestions,
      meetingState: snapshot.meetingState,
      meetingMembers: snapshot.meetingMembers,
      postEvents: snapshot.postEvents + [postEvent],
      personaActivations: snapshot.personaActivations,
      agentRuns: snapshot.agentRuns
    )

    return OrbitPhase1AppendMeetingPromotionEventResult(
      snapshot: updatedSnapshot,
      postEvent: postEvent
    )
  }
}

public protocol OrbitPhase1MeetingPromotionEventServing: Sendable {
  func appendMeetingPromotionEvent(
    _ request: OrbitPhase1AppendMeetingPromotionEventRequest
  ) async throws -> OrbitPhase1AppendMeetingPromotionEventResult
}

public extension OrbitPhase1MeetingPromotionEventService {
  init(
    runtimeStore: OrbitPostgresRuntimeStore,
    now: @escaping @Sendable () -> Date = Date.init,
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
      appendPostEvent: { workspaceID, postEvent, realtimeEvents in
        try await runtimeStore.appendPostEvent(
          workspaceID: workspaceID,
          postEvent,
          realtimeEvents: realtimeEvents
        )
      },
      appendFailure: { workspaceID, systemMessage, postEvent, realtimeEvents, meetingState, timestamp in
        try await runtimeStore.appendActivationFailure(
          workspaceID: workspaceID,
          systemMessage,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents,
          meetingState: meetingState,
          threadLastActivityAt: timestamp
        )
      },
      now: now,
      makePostEventID: makePostEventID
    )
  }
}

extension OrbitPhase1MeetingPromotionEventService: OrbitPhase1MeetingPromotionEventServing {}
