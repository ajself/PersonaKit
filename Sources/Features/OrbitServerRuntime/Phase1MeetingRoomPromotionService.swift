import Foundation

public struct OrbitPhase1PromoteMeetingRoomRequest: Codable, Equatable, Sendable {
  public let originPostID: UUID?
  public let meeting: OrbitPhase1CreateMeetingRoomRequest
  public let promotion: OrbitPhase1MeetingPromotionEventPayload

  public init(
    originPostID: UUID? = nil,
    meeting: OrbitPhase1CreateMeetingRoomRequest,
    promotion: OrbitPhase1MeetingPromotionEventPayload
  ) {
    self.originPostID = originPostID
    self.meeting = meeting
    self.promotion = promotion
  }
}

public struct OrbitPhase1PromoteMeetingRoomResult: Codable, Equatable, Sendable {
  public let meeting: OrbitPhase1CreateMeetingRoomResult
  public let originPostEvent: OrbitPostEventRecord

  public init(
    meeting: OrbitPhase1CreateMeetingRoomResult,
    originPostEvent: OrbitPostEventRecord
  ) {
    self.meeting = meeting
    self.originPostEvent = originPostEvent
  }
}

public enum OrbitPhase1MeetingRoomPromotionServiceError: Error, Equatable {
  case originRoomNotFound
  case createdRoomUnavailable(UUID)
}

public struct OrbitPhase1MeetingRoomPromotionService: Sendable {
  public typealias OriginSnapshotLoader =
    @Sendable (String, String, UUID?) async throws -> OrbitPhase1RoomSnapshot?
  public typealias PreparedMeetingBuilder =
    @Sendable (OrbitPhase1CreateMeetingRoomRequest) async throws -> OrbitPhase1PreparedMeetingRoom
  public typealias PromotedRoomBootstrapper =
    @Sendable (
      OrbitPostEventRecord,
      [OrbitRealtimeEventRecord],
      OrbitPhase1RoomBootstrap
    ) async throws -> Void
  public typealias CreatedRoomLoader =
    @Sendable (String, String, UUID) async throws -> OrbitPhase1RoomSnapshot?

  public let loadOriginSnapshot: OriginSnapshotLoader
  public let prepareMeetingRoom: PreparedMeetingBuilder
  public let bootstrapPromotedMeetingRoom: PromotedRoomBootstrapper
  public let loadCreatedRoom: CreatedRoomLoader
  public let now: @Sendable () -> Date
  public let makePostEventID: @Sendable () -> UUID
  public let makePostLinkID: @Sendable () -> UUID

  public init(
    loadOriginSnapshot: @escaping OriginSnapshotLoader,
    prepareMeetingRoom: @escaping PreparedMeetingBuilder,
    bootstrapPromotedMeetingRoom: @escaping PromotedRoomBootstrapper,
    loadCreatedRoom: @escaping CreatedRoomLoader,
    now: @escaping @Sendable () -> Date = Date.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init,
    makePostLinkID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadOriginSnapshot = loadOriginSnapshot
    self.prepareMeetingRoom = prepareMeetingRoom
    self.bootstrapPromotedMeetingRoom = bootstrapPromotedMeetingRoom
    self.loadCreatedRoom = loadCreatedRoom
    self.now = now
    self.makePostEventID = makePostEventID
    self.makePostLinkID = makePostLinkID
  }

  public func promoteMeetingRoom(
    _ request: OrbitPhase1PromoteMeetingRoomRequest
  ) async throws -> OrbitPhase1PromoteMeetingRoomResult {
    guard let originSnapshot = try await loadOriginSnapshot(
      request.meeting.workspaceSlug,
      request.meeting.channelSlug,
      request.originPostID
    ) else {
      throw OrbitPhase1MeetingRoomPromotionServiceError.originRoomNotFound
    }

    let preparedMeeting = try await prepareMeetingRoom(request.meeting)
    let timestamp = now()
    let continuityLink = OrbitPostLinkRecord(
      id: makePostLinkID(),
      fromPostID: originSnapshot.post.id,
      toPostID: preparedMeeting.bootstrap.post.id,
      linkType: .promotion,
      createdAt: timestamp
    )
    let promotedRoomBootstrap = roomBootstrap(
      from: preparedMeeting.bootstrap,
      appending: continuityLink
    )
    let originPostEvent = OrbitPostEventRecord(
      id: makePostEventID(),
      postID: originSnapshot.post.id,
      threadID: originSnapshot.thread.id,
      eventType: OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(request.promotion),
      createdAt: timestamp
    )
    let originRealtimeEvents = try OrbitPhase1RealtimeEventProjector.postEventOnlyEvents(
      workspaceID: originSnapshot.workspace.id,
      postEvent: originPostEvent
    )

    try await bootstrapPromotedMeetingRoom(
      originPostEvent,
      originRealtimeEvents,
      promotedRoomBootstrap
    )

    guard
      let createdRoom = try await loadCreatedRoom(
        request.meeting.workspaceSlug,
        request.meeting.channelSlug,
        preparedMeeting.bootstrap.post.id
      )
    else {
      throw OrbitPhase1MeetingRoomPromotionServiceError.createdRoomUnavailable(
        preparedMeeting.bootstrap.post.id
      )
    }

    return OrbitPhase1PromoteMeetingRoomResult(
      meeting: OrbitPhase1CreateMeetingRoomResult(
        scope: preparedMeeting.scope,
        snapshot: createdRoom
      ),
      originPostEvent: originPostEvent
    )
  }

  private func roomBootstrap(
    from bootstrap: OrbitPhase1RoomBootstrap,
    appending postLink: OrbitPostLinkRecord
  ) -> OrbitPhase1RoomBootstrap {
    OrbitPhase1RoomBootstrap(
      workspace: bootstrap.workspace,
      channel: bootstrap.channel,
      workspacePersonas: bootstrap.workspacePersonas,
      teams: bootstrap.teams,
      squads: bootstrap.squads,
      workspacePersonaMemberships: bootstrap.workspacePersonaMemberships,
      post: bootstrap.post,
      thread: bootstrap.thread,
      seedMessages: bootstrap.seedMessages,
      realtimeEvents: bootstrap.realtimeEvents,
      postParticipants: bootstrap.postParticipants,
      postLinks: bootstrap.postLinks + [postLink],
      notes: bootstrap.notes,
      decisions: bootstrap.decisions,
      references: bootstrap.references,
      meetingOutputState: bootstrap.meetingOutputState,
      meetingOpenQuestions: bootstrap.meetingOpenQuestions,
      meetingState: bootstrap.meetingState,
      meetingMembers: bootstrap.meetingMembers,
      postEvents: bootstrap.postEvents,
      personaActivations: bootstrap.personaActivations,
      agentRuns: bootstrap.agentRuns
    )
  }
}

public protocol OrbitPhase1MeetingRoomPromotionServing: Sendable {
  func promoteMeetingRoom(
    _ request: OrbitPhase1PromoteMeetingRoomRequest
  ) async throws -> OrbitPhase1PromoteMeetingRoomResult
}

public extension OrbitPhase1MeetingRoomPromotionService {
  init(
    runtimeStore: OrbitPostgresRuntimeStore,
    meetingCreationService: OrbitPhase1MeetingRoomCreationService,
    now: @escaping @Sendable () -> Date = Date.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init,
    makePostLinkID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.init(
      loadOriginSnapshot: { workspaceSlug, channelSlug, postID in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug,
          postID: postID
        )
      },
      prepareMeetingRoom: { request in
        try await meetingCreationService.prepareMeetingRoom(request)
      },
      bootstrapPromotedMeetingRoom: { originPostEvent, originRealtimeEvents, bootstrap in
        try await runtimeStore.promoteMeetingRoom(
          originPostEvent: originPostEvent,
          originRealtimeEvents: originRealtimeEvents,
          room: bootstrap
        )
      },
      loadCreatedRoom: { workspaceSlug, channelSlug, postID in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug,
          postID: postID
        )
      },
      now: now,
      makePostEventID: makePostEventID,
      makePostLinkID: makePostLinkID
    )
  }
}
