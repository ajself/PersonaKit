import Foundation

public struct OrbitPhase1AppendUserMessageRequest: Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let postID: UUID?
  public let authorID: String
  public let body: String

  public init(
    workspaceSlug: String,
    channelSlug: String,
    postID: UUID? = nil,
    authorID: String,
    body: String
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.postID = postID
    self.authorID = authorID
    self.body = body
  }
}

public struct OrbitPhase1AppendUserMessageResult: Codable, Equatable, Sendable {
  public let snapshot: OrbitPhase1RoomSnapshot
  public let message: OrbitMessageRecord

  public init(
    snapshot: OrbitPhase1RoomSnapshot,
    message: OrbitMessageRecord
  ) {
    self.snapshot = snapshot
    self.message = message
  }
}

public enum OrbitPhase1RoomWriteServiceError: Error, Equatable {
  case roomNotFound
}

public struct OrbitPhase1RoomWriteService: Sendable {
  public typealias SnapshotLoader =
    @Sendable (String, String, UUID?) async throws -> OrbitPhase1RoomSnapshot?
  public typealias MessageAppender =
    @Sendable (UUID, OrbitMessageRecord, [OrbitRealtimeEventRecord], OrbitMeetingStateRecord?, Date) async throws -> Void

  public let loadSnapshot: SnapshotLoader
  public let appendMessage: MessageAppender
  public let now: @Sendable () -> Date
  public let makeMessageID: @Sendable () -> UUID

  public init(
    loadSnapshot: @escaping SnapshotLoader,
    appendMessage: @escaping MessageAppender,
    now: @escaping @Sendable () -> Date = Date.init,
    makeMessageID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadSnapshot = loadSnapshot
    self.appendMessage = appendMessage
    self.now = now
    self.makeMessageID = makeMessageID
  }

  public func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult {
    guard let snapshot = try await loadSnapshot(
      request.workspaceSlug,
      request.channelSlug,
      request.postID
    ) else {
      throw OrbitPhase1RoomWriteServiceError.roomNotFound
    }

    let timestamp = now()
    let message = OrbitMessageRecord(
      id: makeMessageID(),
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      authorType: .user,
      authorID: request.authorID,
      body: request.body,
      messageFormat: .plainText,
      state: .persisted,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.appendEvents(
      workspaceID: snapshot.workspace.id,
      message: message,
      threadLastActivityAt: timestamp
    )
    let updatedMeetingState = snapshot.meetingStateAfterConversationMessage()

    try await appendMessage(
      snapshot.workspace.id,
      message,
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
      messages: snapshot.messages + [message],
      postParticipants: snapshot.postParticipants,
      meetingState: updatedMeetingState,
      meetingMembers: snapshot.meetingMembers,
      postEvents: snapshot.postEvents,
      personaActivations: snapshot.personaActivations,
      agentRuns: snapshot.agentRuns
    )

    return OrbitPhase1AppendUserMessageResult(
      snapshot: updatedRoom,
      message: message
    )
  }
}

public protocol OrbitPhase1RoomWriteServing: Sendable {
  func appendUserMessage(
    _ request: OrbitPhase1AppendUserMessageRequest
  ) async throws -> OrbitPhase1AppendUserMessageResult
}

public extension OrbitPhase1RoomWriteService {
  init(
    runtimeStore: OrbitPostgresRuntimeStore,
    now: @escaping @Sendable () -> Date = Date.init,
    makeMessageID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.init(
      loadSnapshot: { workspaceSlug, channelSlug, postID in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug,
          postID: postID
        )
      },
      appendMessage: { workspaceID, message, realtimeEvents, meetingState, timestamp in
        try await runtimeStore.appendMessage(
          workspaceID: workspaceID,
          message,
          realtimeEvents: realtimeEvents,
          meetingState: meetingState,
          threadLastActivityAt: timestamp
        )
      },
      now: now,
      makeMessageID: makeMessageID
    )
  }
}

extension OrbitPhase1RoomWriteService: OrbitPhase1RoomWriteServing {}
