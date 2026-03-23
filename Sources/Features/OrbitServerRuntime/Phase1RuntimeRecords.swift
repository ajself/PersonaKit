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

public enum OrbitMeetingType: String, Codable, Equatable, Sendable {
  case adHoc = "ad_hoc"
  case squad
  case team
  case review
  case planning
  case retrospective
}

public enum OrbitMeetingStatus: String, Codable, Equatable, Sendable {
  case created
  case active
  case summarizing
  case completed
  case failed
}

public enum OrbitMeetingParticipationRole: String, Codable, Equatable, Sendable {
  case facilitator
  case contributor
  case observer
  case summarizer
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

public enum OrbitPostLinkType: String, Codable, Equatable, Sendable {
  case origin
  case followUp = "follow_up"
  case dependency
  case promotion
  case related
}

public enum OrbitStructuredObjectType: String, Codable, Equatable, Sendable {
  case note
  case decision
  case reference
  case artifact
}

public enum OrbitNoteType: String, Codable, Equatable, Sendable {
  case brief
  case detailed
  case meetingSummary = "meeting_summary"
  case retrospective
  case workstreamCloseout = "workstream_closeout"
  case manual
}

public enum OrbitDecisionState: String, Codable, Equatable, Sendable {
  case proposed
  case adopted
  case rejected
  case superseded
}

public enum OrbitReferenceType: String, Codable, Equatable, Sendable {
  case url
  case doc
  case file
  case issue
  case commit
  case externalNote = "external_note"
}

public enum OrbitArtifactType: String, Codable, Equatable, Sendable {
  case file
  case image
  case codeOutput = "code_output"
  case report
  case bundle
  case other
}

public enum OrbitMeetingOutcomeState: String, Codable, Equatable, Sendable {
  case pending
  case decisionRecorded = "decision_recorded"
  case noDecisionRecorded = "no_decision_recorded"
}

public struct OrbitPostLinkRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let fromPostID: UUID
  public let toPostID: UUID
  public let linkType: OrbitPostLinkType
  public let createdAt: Date

  public init(
    id: UUID,
    fromPostID: UUID,
    toPostID: UUID,
    linkType: OrbitPostLinkType,
    createdAt: Date
  ) {
    self.id = id
    self.fromPostID = fromPostID
    self.toPostID = toPostID
    self.linkType = linkType
    self.createdAt = createdAt
  }
}

public struct OrbitNoteRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let noteType: OrbitNoteType
  public let body: String
  public let createdByParticipantType: OrbitParticipantAuthorType
  public let createdByParticipantID: String
  public let createdAt: Date

  public init(
    id: UUID,
    postID: UUID,
    noteType: OrbitNoteType,
    body: String,
    createdByParticipantType: OrbitParticipantAuthorType,
    createdByParticipantID: String,
    createdAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.noteType = noteType
    self.body = body
    self.createdByParticipantType = createdByParticipantType
    self.createdByParticipantID = createdByParticipantID
    self.createdAt = createdAt
  }
}

public struct OrbitStructuredAttachmentRecord: Codable, Equatable, Sendable {
  public let originPostID: UUID
  public let structuredObjectType: OrbitStructuredObjectType
  public let structuredObjectID: UUID
  public let attachmentOrdinal: Int
  public let attachedAt: Date

  public init(
    originPostID: UUID,
    structuredObjectType: OrbitStructuredObjectType,
    structuredObjectID: UUID,
    attachmentOrdinal: Int,
    attachedAt: Date
  ) {
    self.originPostID = originPostID
    self.structuredObjectType = structuredObjectType
    self.structuredObjectID = structuredObjectID
    self.attachmentOrdinal = attachmentOrdinal
    self.attachedAt = attachedAt
  }
}

public struct OrbitDecisionRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let title: String
  public let body: String
  public let decisionState: OrbitDecisionState
  public let rationale: String
  public let tradeoffs: String
  public let dissent: String
  public let linkedReferenceIDs: [UUID]
  public let rationaleNoteID: UUID?
  public let createdByParticipantType: OrbitParticipantAuthorType
  public let createdByParticipantID: String
  public let createdAt: Date

  public init(
    id: UUID,
    postID: UUID,
    title: String,
    body: String,
    decisionState: OrbitDecisionState,
    rationale: String = "none recorded",
    tradeoffs: String = "none recorded",
    dissent: String = "none recorded",
    linkedReferenceIDs: [UUID] = [],
    rationaleNoteID: UUID? = nil,
    createdByParticipantType: OrbitParticipantAuthorType,
    createdByParticipantID: String,
    createdAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.title = title
    self.body = body
    self.decisionState = decisionState
    self.rationale = rationale
    self.tradeoffs = tradeoffs
    self.dissent = dissent
    self.linkedReferenceIDs = linkedReferenceIDs
    self.rationaleNoteID = rationaleNoteID
    self.createdByParticipantType = createdByParticipantType
    self.createdByParticipantID = createdByParticipantID
    self.createdAt = createdAt
  }
}

public struct OrbitReferenceRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let referenceType: OrbitReferenceType
  public let target: String
  public let title: String?
  public let createdByParticipantType: OrbitParticipantAuthorType
  public let createdByParticipantID: String
  public let createdAt: Date

  public init(
    id: UUID,
    postID: UUID,
    referenceType: OrbitReferenceType,
    target: String,
    title: String? = nil,
    createdByParticipantType: OrbitParticipantAuthorType,
    createdByParticipantID: String,
    createdAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.referenceType = referenceType
    self.target = target
    self.title = title
    self.createdByParticipantType = createdByParticipantType
    self.createdByParticipantID = createdByParticipantID
    self.createdAt = createdAt
  }
}

public struct OrbitArtifactRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let artifactType: OrbitArtifactType
  public let storageRef: String
  public let title: String?
  public let createdByParticipantType: OrbitParticipantAuthorType
  public let createdByParticipantID: String
  public let createdAt: Date

  public init(
    id: UUID,
    postID: UUID,
    artifactType: OrbitArtifactType,
    storageRef: String,
    title: String? = nil,
    createdByParticipantType: OrbitParticipantAuthorType,
    createdByParticipantID: String,
    createdAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.artifactType = artifactType
    self.storageRef = storageRef
    self.title = title
    self.createdByParticipantType = createdByParticipantType
    self.createdByParticipantID = createdByParticipantID
    self.createdAt = createdAt
  }
}

public enum OrbitStructuredObjectRecord: Codable, Equatable, Sendable {
  case note(OrbitNoteRecord)
  case decision(OrbitDecisionRecord)
  case reference(OrbitReferenceRecord)
  case artifact(OrbitArtifactRecord)

  public var id: UUID {
    switch self {
    case let .note(record):
      return record.id
    case let .decision(record):
      return record.id
    case let .reference(record):
      return record.id
    case let .artifact(record):
      return record.id
    }
  }

  private enum CodingKeys: String, CodingKey {
    case type
    case note
    case decision
    case reference
    case artifact
  }

  public init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(OrbitStructuredObjectType.self, forKey: .type)

    switch type {
    case .note:
      self = .note(try container.decode(OrbitNoteRecord.self, forKey: .note))
    case .decision:
      self = .decision(try container.decode(OrbitDecisionRecord.self, forKey: .decision))
    case .reference:
      self = .reference(try container.decode(OrbitReferenceRecord.self, forKey: .reference))
    case .artifact:
      self = .artifact(try container.decode(OrbitArtifactRecord.self, forKey: .artifact))
    }
  }

  public func encode(
    to encoder: Encoder
  ) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .note(record):
      try container.encode(OrbitStructuredObjectType.note, forKey: .type)
      try container.encode(record, forKey: .note)
    case let .decision(record):
      try container.encode(OrbitStructuredObjectType.decision, forKey: .type)
      try container.encode(record, forKey: .decision)
    case let .reference(record):
      try container.encode(OrbitStructuredObjectType.reference, forKey: .type)
      try container.encode(record, forKey: .reference)
    case let .artifact(record):
      try container.encode(OrbitStructuredObjectType.artifact, forKey: .type)
      try container.encode(record, forKey: .artifact)
    }
  }
}

public struct OrbitMeetingOutputStateRecord: Codable, Equatable, Sendable {
  public let postID: UUID
  public let outcomeState: OrbitMeetingOutcomeState
  public let detail: String?
  public let recordedByParticipantType: OrbitParticipantAuthorType
  public let recordedByParticipantID: String
  public let recordedAt: Date

  public init(
    postID: UUID,
    outcomeState: OrbitMeetingOutcomeState,
    detail: String? = nil,
    recordedByParticipantType: OrbitParticipantAuthorType,
    recordedByParticipantID: String,
    recordedAt: Date
  ) {
    self.postID = postID
    self.outcomeState = outcomeState
    self.detail = detail
    self.recordedByParticipantType = recordedByParticipantType
    self.recordedByParticipantID = recordedByParticipantID
    self.recordedAt = recordedAt
  }
}

public struct OrbitMeetingOpenQuestionRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let postID: UUID
  public let body: String
  public let createdByParticipantType: OrbitParticipantAuthorType
  public let createdByParticipantID: String
  public let createdAt: Date

  public init(
    id: UUID,
    postID: UUID,
    body: String,
    createdByParticipantType: OrbitParticipantAuthorType,
    createdByParticipantID: String,
    createdAt: Date
  ) {
    self.id = id
    self.postID = postID
    self.body = body
    self.createdByParticipantType = createdByParticipantType
    self.createdByParticipantID = createdByParticipantID
    self.createdAt = createdAt
  }
}

public struct OrbitMeetingStateRecord: Codable, Equatable, Sendable {
  public let postID: UUID
  public let meetingType: OrbitMeetingType
  public let status: OrbitMeetingStatus
  public let startedByParticipantType: OrbitParticipantAuthorType
  public let startedByParticipantID: String
  public let startedAt: Date
  public let completedAt: Date?

  public init(
    postID: UUID,
    meetingType: OrbitMeetingType,
    status: OrbitMeetingStatus,
    startedByParticipantType: OrbitParticipantAuthorType,
    startedByParticipantID: String,
    startedAt: Date,
    completedAt: Date? = nil
  ) {
    self.postID = postID
    self.meetingType = meetingType
    self.status = status
    self.startedByParticipantType = startedByParticipantType
    self.startedByParticipantID = startedByParticipantID
    self.startedAt = startedAt
    self.completedAt = completedAt
  }
}

public struct OrbitMeetingMemberRecord: Codable, Equatable, Sendable {
  public let id: UUID
  public let meetingPostID: UUID
  public let postParticipantID: UUID
  public let participationRole: OrbitMeetingParticipationRole
  public let selectedReason: String
  public let joinedAt: Date
  public let completedAt: Date?

  public init(
    id: UUID,
    meetingPostID: UUID,
    postParticipantID: UUID,
    participationRole: OrbitMeetingParticipationRole,
    selectedReason: String,
    joinedAt: Date,
    completedAt: Date? = nil
  ) {
    self.id = id
    self.meetingPostID = meetingPostID
    self.postParticipantID = postParticipantID
    self.participationRole = participationRole
    self.selectedReason = selectedReason
    self.joinedAt = joinedAt
    self.completedAt = completedAt
  }
}

public struct OrbitPhase1MeetingRoomContext: Equatable, Sendable {
  public let workspace: OrbitWorkspaceRecord
  public let channel: OrbitChannelRecord
  public let workspacePersonas: [OrbitWorkspacePersonaRecord]
  public let teams: [OrbitTeamRecord]
  public let squads: [OrbitSquadRecord]
  public let workspacePersonaMemberships: [OrbitWorkspacePersonaMembershipRecord]

  public init(
    workspace: OrbitWorkspaceRecord,
    channel: OrbitChannelRecord,
    workspacePersonas: [OrbitWorkspacePersonaRecord] = [],
    teams: [OrbitTeamRecord] = [],
    squads: [OrbitSquadRecord] = [],
    workspacePersonaMemberships: [OrbitWorkspacePersonaMembershipRecord] = []
  ) {
    self.workspace = workspace
    self.channel = channel
    self.workspacePersonas = workspacePersonas
    self.teams = teams
    self.squads = squads
    self.workspacePersonaMemberships = workspacePersonaMemberships
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
  public let postLinks: [OrbitPostLinkRecord]
  public let notes: [OrbitNoteRecord]
  public let decisions: [OrbitDecisionRecord]
  public let references: [OrbitReferenceRecord]
  public let artifacts: [OrbitArtifactRecord]
  public let structuredAttachments: [OrbitStructuredAttachmentRecord]
  public let meetingOutputState: OrbitMeetingOutputStateRecord?
  public let meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord]
  public let meetingState: OrbitMeetingStateRecord?
  public let meetingMembers: [OrbitMeetingMemberRecord]
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
    postLinks: [OrbitPostLinkRecord] = [],
    notes: [OrbitNoteRecord] = [],
    decisions: [OrbitDecisionRecord] = [],
    references: [OrbitReferenceRecord] = [],
    artifacts: [OrbitArtifactRecord] = [],
    structuredAttachments: [OrbitStructuredAttachmentRecord]? = nil,
    meetingOutputState: OrbitMeetingOutputStateRecord? = nil,
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord] = [],
    meetingState: OrbitMeetingStateRecord? = nil,
    meetingMembers: [OrbitMeetingMemberRecord] = [],
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
    self.postLinks = postLinks
    self.notes = notes
    self.decisions = decisions
    self.references = references
    self.artifacts = artifacts
    let resolvedStructuredAttachments = structuredAttachments
      ?? orbitDefaultStructuredAttachments(
        postID: post.id,
        notes: notes,
        decisions: decisions,
        references: references,
        artifacts: artifacts
      )
    self.structuredAttachments = resolvedStructuredAttachments.sorted(by: orbitStructuredAttachmentSort)
    self.meetingOutputState = meetingOutputState
    self.meetingOpenQuestions = meetingOpenQuestions
    self.meetingState = meetingState
    self.meetingMembers = meetingMembers
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
  public let postLinks: [OrbitPostLinkRecord]
  public let notes: [OrbitNoteRecord]
  public let decisions: [OrbitDecisionRecord]
  public let references: [OrbitReferenceRecord]
  public let artifacts: [OrbitArtifactRecord]
  public let structuredAttachments: [OrbitStructuredAttachmentRecord]
  public let meetingOutputState: OrbitMeetingOutputStateRecord?
  public let meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord]
  public let meetingState: OrbitMeetingStateRecord?
  public let meetingMembers: [OrbitMeetingMemberRecord]
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
    postLinks: [OrbitPostLinkRecord] = [],
    notes: [OrbitNoteRecord] = [],
    decisions: [OrbitDecisionRecord] = [],
    references: [OrbitReferenceRecord] = [],
    artifacts: [OrbitArtifactRecord] = [],
    structuredAttachments: [OrbitStructuredAttachmentRecord]? = nil,
    meetingOutputState: OrbitMeetingOutputStateRecord? = nil,
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord] = [],
    meetingState: OrbitMeetingStateRecord? = nil,
    meetingMembers: [OrbitMeetingMemberRecord] = [],
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
    self.postLinks = postLinks
    self.notes = notes
    self.decisions = decisions
    self.references = references
    self.artifacts = artifacts
    let resolvedStructuredAttachments = structuredAttachments
      ?? orbitDefaultStructuredAttachments(
        postID: post.id,
        notes: notes,
        decisions: decisions,
        references: references,
        artifacts: artifacts
      )
    self.structuredAttachments = resolvedStructuredAttachments.sorted(by: orbitStructuredAttachmentSort)
    self.meetingOutputState = meetingOutputState
    self.meetingOpenQuestions = meetingOpenQuestions
    self.meetingState = meetingState
    self.meetingMembers = meetingMembers
    self.postEvents = postEvents
    self.personaActivations = personaActivations
    self.agentRuns = agentRuns
  }
}

public extension OrbitPhase1RoomSnapshot {
  func structuredObject(
    for attachment: OrbitStructuredAttachmentRecord
  ) -> OrbitStructuredObjectRecord? {
    guard attachment.originPostID == post.id else {
      return nil
    }

    switch attachment.structuredObjectType {
    case .note:
      return notes
        .first(where: { $0.id == attachment.structuredObjectID })
        .map(OrbitStructuredObjectRecord.note)
    case .decision:
      return decisions
        .first(where: { $0.id == attachment.structuredObjectID })
        .map(OrbitStructuredObjectRecord.decision)
    case .reference:
      return references
        .first(where: { $0.id == attachment.structuredObjectID })
        .map(OrbitStructuredObjectRecord.reference)
    case .artifact:
      return artifacts
        .first(where: { $0.id == attachment.structuredObjectID })
        .map(OrbitStructuredObjectRecord.artifact)
    }
  }

  var orderedStructuredObjects: [OrbitStructuredObjectRecord] {
    structuredAttachments
      .sorted(by: orbitStructuredAttachmentSort)
      .compactMap(structuredObject(for:))
  }

  func meetingStateAfterConversationMessage() -> OrbitMeetingStateRecord? {
    guard post.postType == .meeting else {
      return nil
    }

    guard let meetingState else {
      return nil
    }

    guard meetingState.status == .created else {
      return meetingState
    }

    return OrbitMeetingStateRecord(
      postID: meetingState.postID,
      meetingType: meetingState.meetingType,
      status: .active,
      startedByParticipantType: meetingState.startedByParticipantType,
      startedByParticipantID: meetingState.startedByParticipantID,
      startedAt: meetingState.startedAt,
      completedAt: meetingState.completedAt
    )
  }
}

private struct OrbitDefaultStructuredAttachmentSeed {
  let type: OrbitStructuredObjectType
  let objectID: UUID
  let createdAt: Date
}

private func orbitDefaultStructuredAttachments(
  postID: UUID,
  notes: [OrbitNoteRecord],
  decisions: [OrbitDecisionRecord],
  references: [OrbitReferenceRecord],
  artifacts: [OrbitArtifactRecord]
) -> [OrbitStructuredAttachmentRecord] {
  let seeds =
    notes.map {
      OrbitDefaultStructuredAttachmentSeed(
        type: .note,
        objectID: $0.id,
        createdAt: $0.createdAt
      )
    }
    + decisions.map {
      OrbitDefaultStructuredAttachmentSeed(
        type: .decision,
        objectID: $0.id,
        createdAt: $0.createdAt
      )
    }
    + references.map {
      OrbitDefaultStructuredAttachmentSeed(
        type: .reference,
        objectID: $0.id,
        createdAt: $0.createdAt
      )
    }
    + artifacts.map {
      OrbitDefaultStructuredAttachmentSeed(
        type: .artifact,
        objectID: $0.id,
        createdAt: $0.createdAt
      )
    }

  let sortedSeeds = seeds.sorted(by: orbitDefaultStructuredAttachmentSeedSort)

  return sortedSeeds.enumerated().map { index, seed in
    OrbitStructuredAttachmentRecord(
      originPostID: postID,
      structuredObjectType: seed.type,
      structuredObjectID: seed.objectID,
      attachmentOrdinal: index,
      attachedAt: seed.createdAt
    )
  }
}

private func orbitDefaultStructuredAttachmentSeedSort(
  _ lhs: OrbitDefaultStructuredAttachmentSeed,
  _ rhs: OrbitDefaultStructuredAttachmentSeed
) -> Bool {
  if lhs.createdAt == rhs.createdAt {
    if lhs.type == rhs.type {
      return lhs.objectID.uuidString < rhs.objectID.uuidString
    }

    return lhs.type.rawValue < rhs.type.rawValue
  }

  return lhs.createdAt < rhs.createdAt
}

private func orbitStructuredAttachmentSort(
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
