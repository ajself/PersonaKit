import Foundation

public struct OrbitPhase1ParticipantJoinedPayload: Codable, Equatable, Sendable {
  public let participantType: String
  public let participantID: String
  public let joinedAt: Date
  public let participationMode: String
}

public struct OrbitPhase1MessageCreatedPayload: Codable, Equatable, Sendable {
  public let messageID: UUID
  public let postID: UUID
  public let threadID: UUID
  public let authorType: String
  public let authorID: String
  public let body: String
  public let messageFormat: String
  public let state: String
  public let createdAt: Date
  public let updatedAt: Date
  public let replyToMessageID: UUID?
}

public struct OrbitPhase1ThreadActivityUpdatedPayload: Codable, Equatable, Sendable {
  public let threadID: UUID
  public let lastActivityAt: Date
}

public struct OrbitPhase1ResolvedContractPayload: Codable, Equatable, Sendable {
  public let directiveID: String?
  public let directiveSource: String?
  public let kitIDs: [String]
  public let authorizedSkillIDs: [String]
  public let requiredSkillIDs: [String]
  public let stopPointIDs: [String]
  public let reviewGateIDs: [String]
  public let memoryScopeIDs: [String]

  public init(
    directiveID: String? = nil,
    directiveSource: String? = nil,
    kitIDs: [String] = [],
    authorizedSkillIDs: [String] = [],
    requiredSkillIDs: [String] = [],
    stopPointIDs: [String] = [],
    reviewGateIDs: [String] = [],
    memoryScopeIDs: [String] = []
  ) {
    self.directiveID = directiveID
    self.directiveSource = directiveSource
    self.kitIDs = kitIDs
    self.authorizedSkillIDs = authorizedSkillIDs
    self.requiredSkillIDs = requiredSkillIDs
    self.stopPointIDs = stopPointIDs
    self.reviewGateIDs = reviewGateIDs
    self.memoryScopeIDs = memoryScopeIDs
  }
}

public struct OrbitPhase1ActivationFailurePayload: Codable, Equatable, Sendable {
  public let addressedTargetID: String?
  public let participantID: String?
  public let workspacePersonaID: String?
  public let personaTemplateID: String?
  public let directiveID: String?
  public let triggerSource: String
  public let systemEventMessageID: UUID
  public let requiredSkillIDs: [String]
  public let authorizedSkillIDs: [String]
  public let failureReason: String
  public let systemEventBody: String

  public init(
    addressedTargetID: String? = nil,
    participantID: String? = nil,
    workspacePersonaID: String? = nil,
    personaTemplateID: String? = nil,
    directiveID: String? = nil,
    triggerSource: String,
    systemEventMessageID: UUID,
    requiredSkillIDs: [String] = [],
    authorizedSkillIDs: [String] = [],
    failureReason: String,
    systemEventBody: String
  ) {
    self.addressedTargetID = addressedTargetID
    self.participantID = participantID
    self.workspacePersonaID = workspacePersonaID
    self.personaTemplateID = personaTemplateID
    self.directiveID = directiveID
    self.triggerSource = triggerSource
    self.systemEventMessageID = systemEventMessageID
    self.requiredSkillIDs = requiredSkillIDs
    self.authorizedSkillIDs = authorizedSkillIDs
    self.failureReason = failureReason
    self.systemEventBody = systemEventBody
  }
}

public struct OrbitPhase1MeetingPromotionFailurePayload: Codable, Equatable, Sendable {
  public let systemEventMessageID: UUID
  public let systemEventBody: String
  public let detail: String

  public init(
    systemEventMessageID: UUID,
    systemEventBody: String,
    detail: String
  ) {
    self.systemEventMessageID = systemEventMessageID
    self.systemEventBody = systemEventBody
    self.detail = detail
  }
}

public struct OrbitPhase1MeetingPromotionEventPayload: Codable, Equatable, Sendable {
  public let initiatedByParticipantID: String
  public let addressedTargetKind: String
  public let addressedTargetReferenceID: String
  public let targetDisplayName: String
  public let meetingType: String
  public let title: String
  public let memberWorkspacePersonaIDs: [UUID]
  public let failure: OrbitPhase1MeetingPromotionFailurePayload?

  public init(
    initiatedByParticipantID: String,
    addressedTargetKind: String,
    addressedTargetReferenceID: String,
    targetDisplayName: String,
    meetingType: String,
    title: String,
    memberWorkspacePersonaIDs: [UUID],
    failure: OrbitPhase1MeetingPromotionFailurePayload? = nil
  ) {
    self.initiatedByParticipantID = initiatedByParticipantID
    self.addressedTargetKind = addressedTargetKind
    self.addressedTargetReferenceID = addressedTargetReferenceID
    self.targetDisplayName = targetDisplayName
    self.meetingType = meetingType
    self.title = title
    self.memberWorkspacePersonaIDs = memberWorkspacePersonaIDs
    self.failure = failure
  }
}

public struct OrbitPhase1MeetingCompletionEventPayload: Codable, Equatable, Sendable {
  public let summaryNote: OrbitNoteRecord
  public let meetingOutputState: OrbitMeetingOutputStateRecord
  public let decision: OrbitDecisionRecord?
  public let references: [OrbitReferenceRecord]
  public let meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord]
  public let meetingState: OrbitMeetingStateRecord
  public let threadLastActivityAt: Date

  public init(
    summaryNote: OrbitNoteRecord,
    meetingOutputState: OrbitMeetingOutputStateRecord,
    decision: OrbitDecisionRecord? = nil,
    references: [OrbitReferenceRecord] = [],
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord] = [],
    meetingState: OrbitMeetingStateRecord,
    threadLastActivityAt: Date
  ) {
    self.summaryNote = summaryNote
    self.meetingOutputState = meetingOutputState
    self.decision = decision
    self.references = references
    self.meetingOpenQuestions = meetingOpenQuestions
    self.meetingState = meetingState
    self.threadLastActivityAt = threadLastActivityAt
  }
}

public struct OrbitPhase1ActivationEventPayload: Codable, Equatable, Sendable {
  public let activationID: UUID?
  public let initiatedByParticipantType: String?
  public let initiatedByParticipantID: String?
  public let triggerMessageID: UUID?
  public let addressedTargetKind: String?
  public let addressedTargetReferenceID: String?
  public let resolvedWorkspacePersonaInstanceID: UUID?
  public let responseMode: String?
  public let agentRunID: UUID?
  public let runnerKind: String?
  public let agentRunStatus: String?
  public let agentRunStartedAt: Date?
  public let agentRunCompletedAt: Date?
  public let contract: OrbitPhase1ResolvedContractPayload?
  public let failure: OrbitPhase1ActivationFailurePayload?
  public let reason: String?

  public init(
    activationID: UUID?,
    initiatedByParticipantType: String? = nil,
    initiatedByParticipantID: String? = nil,
    triggerMessageID: UUID? = nil,
    addressedTargetKind: String? = nil,
    addressedTargetReferenceID: String? = nil,
    resolvedWorkspacePersonaInstanceID: UUID? = nil,
    responseMode: String? = nil,
    agentRunID: UUID? = nil,
    runnerKind: String? = nil,
    agentRunStatus: String? = nil,
    agentRunStartedAt: Date? = nil,
    agentRunCompletedAt: Date? = nil,
    contract: OrbitPhase1ResolvedContractPayload? = nil,
    failure: OrbitPhase1ActivationFailurePayload? = nil,
    reason: String? = nil
  ) {
    self.activationID = activationID
    self.initiatedByParticipantType = initiatedByParticipantType
    self.initiatedByParticipantID = initiatedByParticipantID
    self.triggerMessageID = triggerMessageID
    self.addressedTargetKind = addressedTargetKind
    self.addressedTargetReferenceID = addressedTargetReferenceID
    self.resolvedWorkspacePersonaInstanceID = resolvedWorkspacePersonaInstanceID
    self.responseMode = responseMode
    self.agentRunID = agentRunID
    self.runnerKind = runnerKind
    self.agentRunStatus = agentRunStatus
    self.agentRunStartedAt = agentRunStartedAt
    self.agentRunCompletedAt = agentRunCompletedAt
    self.contract = contract
    self.failure = failure
    self.reason = reason
  }
}

public extension OrbitPhase1ActivationEventPayload {
  init(
    activation: OrbitPersonaActivationRecord,
    agentRun: OrbitAgentRunRecord? = nil,
    contract: OrbitPhase1ResolvedContractPayload? = nil,
    reason: String? = nil
  ) {
    self.init(
      activationID: activation.id,
      initiatedByParticipantType: activation.initiatedByParticipantType.rawValue,
      initiatedByParticipantID: activation.initiatedByParticipantID,
      triggerMessageID: activation.triggerMessageID,
      addressedTargetKind: activation.addressedTargetKind.rawValue,
      addressedTargetReferenceID: activation.addressedTargetReferenceID,
      resolvedWorkspacePersonaInstanceID: activation.resolvedWorkspacePersonaInstanceID,
      responseMode: activation.responseMode.rawValue,
      agentRunID: agentRun?.id,
      runnerKind: agentRun?.runnerKind,
      agentRunStatus: agentRun?.status.rawValue,
      agentRunStartedAt: agentRun?.startedAt,
      agentRunCompletedAt: agentRun?.completedAt,
      contract: contract,
      reason: reason
    )
  }
}

public enum OrbitPhase1RealtimeEventPayloadCodec {
  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  private static let decoder = JSONDecoder()

  public static func encode<T: Encodable & Sendable>(
    _ value: T
  ) throws -> String {
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
  }

  public static func decode<T: Decodable & Sendable>(
    _ type: T.Type,
    from payloadJSON: String
  ) throws -> T {
    try decoder.decode(T.self, from: Data(payloadJSON.utf8))
  }
}
