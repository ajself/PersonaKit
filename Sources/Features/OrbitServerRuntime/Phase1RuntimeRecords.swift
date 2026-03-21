import Foundation

public enum OrbitWorkspaceStatus: String, Codable, Equatable, Sendable {
  case active
  case paused
  case archived
}

public enum OrbitChannelStatus: String, Codable, Equatable, Sendable {
  case active
  case archived
}

public enum OrbitWorkspacePersonaStatus: String, Codable, Equatable, Sendable {
  case active
  case archived
}

public enum OrbitPostType: String, Codable, Equatable, Sendable {
  case message
  case meeting
  case workstream
}

public enum OrbitPostStatus: String, Codable, Equatable, Sendable {
  case active
  case paused
  case completed
  case archived
}

public enum OrbitParticipantAuthorType: String, Codable, Equatable, Sendable {
  case user
  case workspacePersona = "workspace_persona"
  case system
}

public enum OrbitParticipationMode: String, Codable, Equatable, Sendable {
  case active
  case observing
  case invited
  case coordinatorManaged = "coordinator_managed"
}

public enum OrbitThreadStatus: String, Codable, Equatable, Sendable {
  case open
  case closed
  case archived
}

public enum OrbitMessageFormat: String, Codable, Equatable, Sendable {
  case plainText = "plain_text"
  case markdown
  case structured
}

public enum OrbitMessageState: String, Codable, Equatable, Sendable {
  case drafted
  case persisted
  case inProgress = "in_progress"
  case completed
  case failed
  case superseded
}

public enum OrbitAddressedTargetKind: String, Codable, Equatable, Sendable {
  case collaborator
  case team
  case squad
}

public enum OrbitCanonicalResponseMode: String, Codable, Equatable, Sendable {
  case currentThread = "current-thread"
  case directAddress = "direct-address"
  case lightweightMeeting = "lightweight-meeting"
}

public enum OrbitAgentRunStatus: String, Codable, Equatable, Sendable {
  case queued
  case running
  case completed
  case failed
  case cancelled
}

public struct OrbitWorkspaceRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let slug: String
  public let name: String
  public let status: OrbitWorkspaceStatus
  public let createdAt: Date
  public let archivedAt: Date?

  public init(
    id: UUID,
    slug: String,
    name: String,
    status: OrbitWorkspaceStatus,
    createdAt: Date,
    archivedAt: Date? = nil
  ) {
    self.id = id
    self.slug = slug
    self.name = name
    self.status = status
    self.createdAt = createdAt
    self.archivedAt = archivedAt
  }
}

public struct OrbitChannelRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let slug: String
  public let name: String
  public let purpose: String
  public let status: OrbitChannelStatus
  public let createdAt: Date
  public let archivedAt: Date?

  public init(
    id: UUID,
    workspaceID: UUID,
    slug: String,
    name: String,
    purpose: String,
    status: OrbitChannelStatus,
    createdAt: Date,
    archivedAt: Date? = nil
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.slug = slug
    self.name = name
    self.purpose = purpose
    self.status = status
    self.createdAt = createdAt
    self.archivedAt = archivedAt
  }
}

public struct OrbitWorkspacePersonaRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let personaTemplateID: String
  public let displayName: String
  public let defaultDirectiveOverrideID: String?
  public let status: OrbitWorkspacePersonaStatus
  public let createdAt: Date
  public let archivedAt: Date?

  public init(
    id: UUID,
    workspaceID: UUID,
    personaTemplateID: String,
    displayName: String,
    defaultDirectiveOverrideID: String? = nil,
    status: OrbitWorkspacePersonaStatus,
    createdAt: Date,
    archivedAt: Date? = nil
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.personaTemplateID = personaTemplateID
    self.displayName = displayName
    self.defaultDirectiveOverrideID = defaultDirectiveOverrideID
    self.status = status
    self.createdAt = createdAt
    self.archivedAt = archivedAt
  }
}

public struct OrbitTeamRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let slug: String
  public let name: String
  public let purpose: String
  public let createdAt: Date

  public init(
    id: UUID,
    workspaceID: UUID,
    slug: String,
    name: String,
    purpose: String,
    createdAt: Date
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.slug = slug
    self.name = name
    self.purpose = purpose
    self.createdAt = createdAt
  }
}

public struct OrbitSquadRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let teamID: UUID?
  public let slug: String
  public let name: String
  public let purpose: String
  public let createdAt: Date

  public init(
    id: UUID,
    workspaceID: UUID,
    teamID: UUID? = nil,
    slug: String,
    name: String,
    purpose: String,
    createdAt: Date
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.teamID = teamID
    self.slug = slug
    self.name = name
    self.purpose = purpose
    self.createdAt = createdAt
  }
}

public struct OrbitWorkspacePersonaMembershipRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspacePersonaID: UUID
  public let teamID: UUID?
  public let squadID: UUID?
  public let roleInGroup: String
  public let createdAt: Date

  public init(
    id: UUID,
    workspacePersonaID: UUID,
    teamID: UUID? = nil,
    squadID: UUID? = nil,
    roleInGroup: String,
    createdAt: Date
  ) {
    self.id = id
    self.workspacePersonaID = workspacePersonaID
    self.teamID = teamID
    self.squadID = squadID
    self.roleInGroup = roleInGroup
    self.createdAt = createdAt
  }
}

public struct OrbitPostRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let channelID: UUID
  public let postType: OrbitPostType
  public let createdByParticipantType: OrbitParticipantAuthorType
  public let createdByParticipantID: String
  public let title: String?
  public let status: OrbitPostStatus
  public let createdAt: Date
  public let archivedAt: Date?

  public init(
    id: UUID,
    workspaceID: UUID,
    channelID: UUID,
    postType: OrbitPostType,
    createdByParticipantType: OrbitParticipantAuthorType,
    createdByParticipantID: String,
    title: String? = nil,
    status: OrbitPostStatus,
    createdAt: Date,
    archivedAt: Date? = nil
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.channelID = channelID
    self.postType = postType
    self.createdByParticipantType = createdByParticipantType
    self.createdByParticipantID = createdByParticipantID
    self.title = title
    self.status = status
    self.createdAt = createdAt
    self.archivedAt = archivedAt
  }
}

public struct OrbitThreadRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let status: OrbitThreadStatus
  public let lastActivityAt: Date
  public let createdAt: Date
  public let closedAt: Date?

  public init(
    id: UUID,
    postID: UUID,
    status: OrbitThreadStatus,
    lastActivityAt: Date,
    createdAt: Date,
    closedAt: Date? = nil
  ) {
    self.id = id
    self.postID = postID
    self.status = status
    self.lastActivityAt = lastActivityAt
    self.createdAt = createdAt
    self.closedAt = closedAt
  }
}

public struct OrbitMessageRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let threadID: UUID
  public let authorType: OrbitParticipantAuthorType
  public let authorID: String
  public let replyToMessageID: UUID?
  public let body: String
  public let messageFormat: OrbitMessageFormat
  public let state: OrbitMessageState
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    postID: UUID,
    threadID: UUID,
    authorType: OrbitParticipantAuthorType,
    authorID: String,
    replyToMessageID: UUID? = nil,
    body: String,
    messageFormat: OrbitMessageFormat,
    state: OrbitMessageState,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.threadID = threadID
    self.authorType = authorType
    self.authorID = authorID
    self.replyToMessageID = replyToMessageID
    self.body = body
    self.messageFormat = messageFormat
    self.state = state
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct OrbitPostParticipantRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let participantType: OrbitParticipantAuthorType
  public let participantID: String
  public let joinedAt: Date
  public let leftAt: Date?
  public let participationMode: OrbitParticipationMode

  public init(
    id: UUID,
    postID: UUID,
    participantType: OrbitParticipantAuthorType,
    participantID: String,
    joinedAt: Date,
    leftAt: Date? = nil,
    participationMode: OrbitParticipationMode
  ) {
    self.id = id
    self.postID = postID
    self.participantType = participantType
    self.participantID = participantID
    self.joinedAt = joinedAt
    self.leftAt = leftAt
    self.participationMode = participationMode
  }
}

public struct OrbitPostEventRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let threadID: UUID?
  public let eventType: String
  public let payloadJSON: String
  public let createdAt: Date

  public init(
    id: UUID,
    postID: UUID,
    threadID: UUID? = nil,
    eventType: String,
    payloadJSON: String,
    createdAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.threadID = threadID
    self.eventType = eventType
    self.payloadJSON = payloadJSON
    self.createdAt = createdAt
  }
}

public struct OrbitRealtimeEventRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let workspaceID: UUID
  public let postID: UUID?
  public let threadID: UUID?
  public let category: OrbitPhase1RealtimeEventCategory
  public let payloadJSON: String
  public let createdAt: Date

  public init(
    id: UUID,
    workspaceID: UUID,
    postID: UUID? = nil,
    threadID: UUID? = nil,
    category: OrbitPhase1RealtimeEventCategory,
    payloadJSON: String,
    createdAt: Date
  ) {
    self.id = id
    self.workspaceID = workspaceID
    self.postID = postID
    self.threadID = threadID
    self.category = category
    self.payloadJSON = payloadJSON
    self.createdAt = createdAt
  }
}

public struct OrbitPersonaActivationRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let initiatedByParticipantType: OrbitParticipantAuthorType
  public let initiatedByParticipantID: String
  public let workspaceID: UUID
  public let channelID: UUID?
  public let originPostID: UUID
  public let originThreadID: UUID
  public let triggerMessageID: UUID
  public let addressedTargetKind: OrbitAddressedTargetKind
  public let addressedTargetReferenceID: String
  public let resolvedWorkspacePersonaInstanceID: UUID
  public let responseMode: OrbitCanonicalResponseMode
  public let createdAt: Date

  public init(
    id: UUID,
    initiatedByParticipantType: OrbitParticipantAuthorType,
    initiatedByParticipantID: String,
    workspaceID: UUID,
    channelID: UUID? = nil,
    originPostID: UUID,
    originThreadID: UUID,
    triggerMessageID: UUID,
    addressedTargetKind: OrbitAddressedTargetKind,
    addressedTargetReferenceID: String,
    resolvedWorkspacePersonaInstanceID: UUID,
    responseMode: OrbitCanonicalResponseMode,
    createdAt: Date
  ) {
    self.id = id
    self.initiatedByParticipantType = initiatedByParticipantType
    self.initiatedByParticipantID = initiatedByParticipantID
    self.workspaceID = workspaceID
    self.channelID = channelID
    self.originPostID = originPostID
    self.originThreadID = originThreadID
    self.triggerMessageID = triggerMessageID
    self.addressedTargetKind = addressedTargetKind
    self.addressedTargetReferenceID = addressedTargetReferenceID
    self.resolvedWorkspacePersonaInstanceID = resolvedWorkspacePersonaInstanceID
    self.responseMode = responseMode
    self.createdAt = createdAt
  }
}

public struct OrbitAgentRunRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let personaActivationID: UUID
  public let runnerKind: String
  public let status: OrbitAgentRunStatus
  public let startedAt: Date
  public let completedAt: Date?
  public let failureReason: String?

  public init(
    id: UUID,
    personaActivationID: UUID,
    runnerKind: String,
    status: OrbitAgentRunStatus,
    startedAt: Date,
    completedAt: Date? = nil,
    failureReason: String? = nil
  ) {
    self.id = id
    self.personaActivationID = personaActivationID
    self.runnerKind = runnerKind
    self.status = status
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.failureReason = failureReason
  }
}

public struct OrbitPhase1RoomBootstrap: Codable, Equatable, Sendable {
  public let workspace: OrbitWorkspaceRecord
  public let channel: OrbitChannelRecord
  public let workspacePersonas: [OrbitWorkspacePersonaRecord]
  public let teams: [OrbitTeamRecord]
  public let squads: [OrbitSquadRecord]
  public let workspacePersonaMemberships: [OrbitWorkspacePersonaMembershipRecord]
  public let post: OrbitPostRecord
  public let thread: OrbitThreadRecord
  public let seedMessages: [OrbitMessageRecord]
  public let realtimeEvents: [OrbitRealtimeEventRecord]
  public let postParticipants: [OrbitPostParticipantRecord]
  public let postEvents: [OrbitPostEventRecord]
  public let personaActivations: [OrbitPersonaActivationRecord]
  public let agentRuns: [OrbitAgentRunRecord]

  public init(
    workspace: OrbitWorkspaceRecord,
    channel: OrbitChannelRecord,
    workspacePersonas: [OrbitWorkspacePersonaRecord] = [],
    teams: [OrbitTeamRecord] = [],
    squads: [OrbitSquadRecord] = [],
    workspacePersonaMemberships: [OrbitWorkspacePersonaMembershipRecord] = [],
    post: OrbitPostRecord,
    thread: OrbitThreadRecord,
    seedMessages: [OrbitMessageRecord],
    realtimeEvents: [OrbitRealtimeEventRecord] = [],
    postParticipants: [OrbitPostParticipantRecord] = [],
    postEvents: [OrbitPostEventRecord] = [],
    personaActivations: [OrbitPersonaActivationRecord] = [],
    agentRuns: [OrbitAgentRunRecord] = []
  ) {
    self.workspace = workspace
    self.channel = channel
    self.workspacePersonas = workspacePersonas
    self.teams = teams
    self.squads = squads
    self.workspacePersonaMemberships = workspacePersonaMemberships
    self.post = post
    self.thread = thread
    self.seedMessages = seedMessages
    self.realtimeEvents = realtimeEvents
    self.postParticipants = postParticipants
    self.postEvents = postEvents
    self.personaActivations = personaActivations
    self.agentRuns = agentRuns
  }
}

public struct OrbitPhase1RoomSnapshot: Codable, Equatable, Sendable {
  public let workspace: OrbitWorkspaceRecord
  public let channel: OrbitChannelRecord
  public let workspacePersonas: [OrbitWorkspacePersonaRecord]
  public let teams: [OrbitTeamRecord]
  public let squads: [OrbitSquadRecord]
  public let workspacePersonaMemberships: [OrbitWorkspacePersonaMembershipRecord]
  public let post: OrbitPostRecord
  public let thread: OrbitThreadRecord
  public let messages: [OrbitMessageRecord]
  public let postParticipants: [OrbitPostParticipantRecord]
  public let postEvents: [OrbitPostEventRecord]
  public let personaActivations: [OrbitPersonaActivationRecord]
  public let agentRuns: [OrbitAgentRunRecord]

  public init(
    workspace: OrbitWorkspaceRecord,
    channel: OrbitChannelRecord,
    workspacePersonas: [OrbitWorkspacePersonaRecord] = [],
    teams: [OrbitTeamRecord] = [],
    squads: [OrbitSquadRecord] = [],
    workspacePersonaMemberships: [OrbitWorkspacePersonaMembershipRecord] = [],
    post: OrbitPostRecord,
    thread: OrbitThreadRecord,
    messages: [OrbitMessageRecord],
    postParticipants: [OrbitPostParticipantRecord] = [],
    postEvents: [OrbitPostEventRecord] = [],
    personaActivations: [OrbitPersonaActivationRecord] = [],
    agentRuns: [OrbitAgentRunRecord] = []
  ) {
    self.workspace = workspace
    self.channel = channel
    self.workspacePersonas = workspacePersonas
    self.teams = teams
    self.squads = squads
    self.workspacePersonaMemberships = workspacePersonaMemberships
    self.post = post
    self.thread = thread
    self.messages = messages
    self.postParticipants = postParticipants
    self.postEvents = postEvents
    self.personaActivations = personaActivations
    self.agentRuns = agentRuns
  }
}
