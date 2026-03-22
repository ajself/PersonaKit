import Foundation

public struct OrbitPhase1MeetingMemberSpec: Codable, Equatable, Sendable {
  public let workspacePersonaID: UUID
  public let participationRole: OrbitMeetingParticipationRole
  public let selectedReason: String

  public init(
    workspacePersonaID: UUID,
    participationRole: OrbitMeetingParticipationRole,
    selectedReason: String
  ) {
    self.workspacePersonaID = workspacePersonaID
    self.participationRole = participationRole
    self.selectedReason = selectedReason
  }
}

public struct OrbitPhase1CreateMeetingRoomRequest: Codable, Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let title: String
  public let meetingType: OrbitMeetingType
  public let startedByParticipantType: OrbitParticipantAuthorType
  public let startedByParticipantID: String
  public let members: [OrbitPhase1MeetingMemberSpec]

  public init(
    workspaceSlug: String,
    channelSlug: String,
    title: String,
    meetingType: OrbitMeetingType,
    startedByParticipantType: OrbitParticipantAuthorType,
    startedByParticipantID: String,
    members: [OrbitPhase1MeetingMemberSpec]
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.title = title
    self.meetingType = meetingType
    self.startedByParticipantType = startedByParticipantType
    self.startedByParticipantID = startedByParticipantID
    self.members = members
  }
}

public struct OrbitPhase1CreateMeetingRoomResult: Codable, Equatable, Sendable {
  public let scope: OrbitPhase1RealtimeSubscriptionScope
  public let snapshot: OrbitPhase1RoomSnapshot

  public init(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    snapshot: OrbitPhase1RoomSnapshot
  ) {
    self.scope = scope
    self.snapshot = snapshot
  }
}

public struct OrbitPhase1PreparedMeetingRoom: Sendable {
  public let scope: OrbitPhase1RealtimeSubscriptionScope
  public let bootstrap: OrbitPhase1RoomBootstrap

  public init(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    bootstrap: OrbitPhase1RoomBootstrap
  ) {
    self.scope = scope
    self.bootstrap = bootstrap
  }
}

public enum OrbitPhase1MeetingRoomCreationServiceError: Error, Equatable {
  case roomContextNotFound
  case duplicateWorkspacePersona(UUID)
  case workspacePersonaNotFound(UUID)
  case createdRoomUnavailable(UUID)
}

public struct OrbitPhase1MeetingRoomCreationService: Sendable {
  public typealias ContextLoader =
    @Sendable (String, String) async throws -> OrbitPhase1MeetingRoomContext?
  public typealias CreatedRoomLoader =
    @Sendable (String, String, UUID) async throws -> OrbitPhase1RoomSnapshot?
  public typealias RoomBootstrapper =
    @Sendable (OrbitPhase1RoomBootstrap) async throws -> Void

  public let loadContext: ContextLoader
  public let loadCreatedRoom: CreatedRoomLoader
  public let bootstrapRoom: RoomBootstrapper
  public let now: @Sendable () -> Date
  public let makePostID: @Sendable () -> UUID
  public let makeThreadID: @Sendable () -> UUID
  public let makePostParticipantID: @Sendable () -> UUID

  public init(
    loadContext: @escaping ContextLoader,
    loadCreatedRoom: @escaping CreatedRoomLoader,
    bootstrapRoom: @escaping RoomBootstrapper,
    now: @escaping @Sendable () -> Date = Date.init,
    makePostID: @escaping @Sendable () -> UUID = UUID.init,
    makeThreadID: @escaping @Sendable () -> UUID = UUID.init,
    makePostParticipantID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadContext = loadContext
    self.loadCreatedRoom = loadCreatedRoom
    self.bootstrapRoom = bootstrapRoom
    self.now = now
    self.makePostID = makePostID
    self.makeThreadID = makeThreadID
    self.makePostParticipantID = makePostParticipantID
  }

  public func createMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1CreateMeetingRoomResult {
    let preparedMeeting = try await prepareMeetingRoom(request)

    try await bootstrapRoom(preparedMeeting.bootstrap)

    guard
      let snapshot = try await loadCreatedRoom(
        request.workspaceSlug,
        request.channelSlug,
        preparedMeeting.bootstrap.post.id
      )
    else {
      throw OrbitPhase1MeetingRoomCreationServiceError.createdRoomUnavailable(
        preparedMeeting.bootstrap.post.id
      )
    }

    return OrbitPhase1CreateMeetingRoomResult(
      scope: preparedMeeting.scope,
      snapshot: snapshot
    )
  }

  func prepareMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1PreparedMeetingRoom {
    guard let context = try await loadContext(request.workspaceSlug, request.channelSlug) else {
      throw OrbitPhase1MeetingRoomCreationServiceError.roomContextNotFound
    }

    let sortedMembers = request.members.sorted { lhs, rhs in
      lhs.workspacePersonaID.uuidString < rhs.workspacePersonaID.uuidString
    }

    var seenWorkspacePersonaIDs = Set<UUID>()
    for member in sortedMembers {
      let inserted = seenWorkspacePersonaIDs.insert(member.workspacePersonaID).inserted

      guard inserted else {
        throw OrbitPhase1MeetingRoomCreationServiceError.duplicateWorkspacePersona(
          member.workspacePersonaID
        )
      }
    }

    let workspacePersonasByID = Dictionary(
      uniqueKeysWithValues: context.workspacePersonas.map { ($0.id, $0) }
    )

    for member in sortedMembers {
      guard workspacePersonasByID[member.workspacePersonaID] != nil else {
        throw OrbitPhase1MeetingRoomCreationServiceError.workspacePersonaNotFound(
          member.workspacePersonaID
        )
      }
    }

    let createdAt = now()
    let postID = makePostID()
    let threadID = makeThreadID()
    let post = OrbitPostRecord(
      id: postID,
      workspaceID: context.workspace.id,
      channelID: context.channel.id,
      postType: .meeting,
      createdByParticipantType: request.startedByParticipantType,
      createdByParticipantID: request.startedByParticipantID,
      title: request.title,
      status: .active,
      createdAt: createdAt
    )
    let thread = OrbitThreadRecord(
      id: threadID,
      postID: postID,
      status: .open,
      lastActivityAt: createdAt,
      createdAt: createdAt
    )
    let participantRecords = sortedMembers.map { member in
      OrbitPostParticipantRecord(
        id: makePostParticipantID(),
        postID: postID,
        participantType: .workspacePersona,
        participantID: member.workspacePersonaID.uuidString,
        joinedAt: createdAt,
        participationMode: .active
      )
    }
    let meetingMembers = zip(sortedMembers, participantRecords).map { member, participant in
      OrbitMeetingMemberRecord(
        id: participant.id,
        meetingPostID: postID,
        postParticipantID: participant.id,
        participationRole: member.participationRole,
        selectedReason: member.selectedReason,
        joinedAt: createdAt
      )
    }
    let meetingState = OrbitMeetingStateRecord(
      postID: postID,
      meetingType: request.meetingType,
      status: .created,
      startedByParticipantType: request.startedByParticipantType,
      startedByParticipantID: request.startedByParticipantID,
      startedAt: createdAt
    )
    let bootstrap = OrbitPhase1RoomBootstrap(
      workspace: context.workspace,
      channel: context.channel,
      workspacePersonas: context.workspacePersonas,
      teams: context.teams,
      squads: context.squads,
      workspacePersonaMemberships: context.workspacePersonaMemberships,
      post: post,
      thread: thread,
      seedMessages: [],
      postParticipants: participantRecords,
      meetingState: meetingState,
      meetingMembers: meetingMembers
    )

    return OrbitPhase1PreparedMeetingRoom(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: request.workspaceSlug,
        channelSlug: request.channelSlug,
        postID: postID
      ),
      bootstrap: bootstrap
    )
  }
}

public protocol OrbitPhase1MeetingRoomCreationServing: Sendable {
  func createMeetingRoom(
    _ request: OrbitPhase1CreateMeetingRoomRequest
  ) async throws -> OrbitPhase1CreateMeetingRoomResult
}

public extension OrbitPhase1MeetingRoomCreationService {
  init(
    runtimeStore: OrbitPostgresRuntimeStore,
    now: @escaping @Sendable () -> Date = Date.init,
    makePostID: @escaping @Sendable () -> UUID = UUID.init,
    makeThreadID: @escaping @Sendable () -> UUID = UUID.init,
    makePostParticipantID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.init(
      loadContext: { workspaceSlug, channelSlug in
        try await runtimeStore.loadMeetingRoomContext(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug
        )
      },
      loadCreatedRoom: { workspaceSlug, channelSlug, postID in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug,
          postID: postID
        )
      },
      bootstrapRoom: { bootstrap in
        try await runtimeStore.bootstrapRoom(bootstrap)
      },
      now: now,
      makePostID: makePostID,
      makeThreadID: makeThreadID,
      makePostParticipantID: makePostParticipantID
    )
  }
}

extension OrbitPhase1MeetingRoomCreationService: OrbitPhase1MeetingRoomCreationServing {}
