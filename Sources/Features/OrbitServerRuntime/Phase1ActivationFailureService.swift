import Foundation

public struct OrbitPhase1AppendActivationFailureRequest: Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let postID: UUID?
  public let initiatedByParticipantID: String
  public let triggerMessageID: UUID
  public let failure: OrbitPhase1ActivationFailurePayload

  public init(
    workspaceSlug: String,
    channelSlug: String,
    postID: UUID? = nil,
    initiatedByParticipantID: String,
    triggerMessageID: UUID,
    failure: OrbitPhase1ActivationFailurePayload
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.postID = postID
    self.initiatedByParticipantID = initiatedByParticipantID
    self.triggerMessageID = triggerMessageID
    self.failure = failure
  }
}

public struct OrbitPhase1AppendActivationFailureResult: Codable, Equatable, Sendable {
  public let snapshot: OrbitPhase1RoomSnapshot
  public let systemMessage: OrbitMessageRecord
  public let postEvent: OrbitPostEventRecord

  public init(
    snapshot: OrbitPhase1RoomSnapshot,
    systemMessage: OrbitMessageRecord,
    postEvent: OrbitPostEventRecord
  ) {
    self.snapshot = snapshot
    self.systemMessage = systemMessage
    self.postEvent = postEvent
  }
}

public enum OrbitPhase1ActivationFailureServiceError: Error, Equatable {
  case roomNotFound
  case triggerMessageNotFound
}

public struct OrbitPhase1ActivationFailureService: Sendable {
  public typealias SnapshotLoader =
    @Sendable (String, String, UUID?) async throws -> OrbitPhase1RoomSnapshot?
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
  public let appendFailure: FailureAppender
  public let now: @Sendable () -> Date
  public let makePostEventID: @Sendable () -> UUID

  public init(
    loadSnapshot: @escaping SnapshotLoader,
    appendFailure: @escaping FailureAppender,
    now: @escaping @Sendable () -> Date = Date.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadSnapshot = loadSnapshot
    self.appendFailure = appendFailure
    self.now = now
    self.makePostEventID = makePostEventID
  }

  public func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult {
    guard let snapshot = try await loadSnapshot(
      request.workspaceSlug,
      request.channelSlug,
      request.postID
    ) else {
      throw OrbitPhase1ActivationFailureServiceError.roomNotFound
    }

    guard snapshot.messages.contains(where: { $0.id == request.triggerMessageID }) else {
      throw OrbitPhase1ActivationFailureServiceError.triggerMessageNotFound
    }

    let timestamp = now()
    let systemMessage = OrbitMessageRecord(
      id: request.failure.systemEventMessageID,
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      authorType: .system,
      authorID: "orbit-system",
      replyToMessageID: request.triggerMessageID,
      body: request.failure.systemEventBody,
      messageFormat: .plainText,
      state: .completed,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    let postEvent = OrbitPostEventRecord(
      id: makePostEventID(),
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      eventType: OrbitPhase1RealtimeEventCategory.activationFailed.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activationID: nil,
          initiatedByParticipantType: OrbitParticipantAuthorType.user.rawValue,
          initiatedByParticipantID: request.initiatedByParticipantID,
          triggerMessageID: request.triggerMessageID,
          failure: request.failure,
          reason: request.failure.failureReason
        )
      ),
      createdAt: timestamp
    )
    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.activationFailureEvents(
      workspaceID: snapshot.workspace.id,
      systemMessage: systemMessage,
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      eventID: postEvent.id,
      payloadJSON: postEvent.payloadJSON,
      threadLastActivityAt: timestamp
    )
    let updatedMeetingState = snapshot.meetingState

    try await appendFailure(
      snapshot.workspace.id,
      systemMessage,
      postEvent,
      realtimeEvents,
      updatedMeetingState,
      timestamp
    )

    let updatedRoom = OrbitPhase1RoomSnapshot(
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
      meetingState: updatedMeetingState,
      meetingMembers: snapshot.meetingMembers,
      postEvents: snapshot.postEvents + [postEvent],
      personaActivations: snapshot.personaActivations,
      agentRuns: snapshot.agentRuns
    )

    return OrbitPhase1AppendActivationFailureResult(
      snapshot: updatedRoom,
      systemMessage: systemMessage,
      postEvent: postEvent
    )
  }
}

public protocol OrbitPhase1ActivationFailureServing: Sendable {
  func appendActivationFailure(
    _ request: OrbitPhase1AppendActivationFailureRequest
  ) async throws -> OrbitPhase1AppendActivationFailureResult
}

public extension OrbitPhase1ActivationFailureService {
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

extension OrbitPhase1ActivationFailureService: OrbitPhase1ActivationFailureServing {}
