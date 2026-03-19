import Foundation

struct OrbitWorkspace: Codable, Equatable {
  static let currentSchemaVersion = 4

  var schemaVersion = OrbitWorkspace.currentSchemaVersion
  var id: String
  var displayName: String
  var purpose: String
  var participants: [OrbitParticipant]
  var activeThreadID: String
  var threads: [OrbitConversationThread]
  var activationRecords: [OrbitActivationRecord]
  var activationContractSnapshots: [OrbitActivationContractSnapshot]
  var activationFailureRecords: [OrbitActivationFailureRecord]
  var nextMessageSequence: Int
  var nextActivationSequence: Int
  var nextActivationFailureSequence: Int

  var activeThread: OrbitConversationThread? {
    threads.first { $0.id == activeThreadID }
  }

  func participant(
    id: String
  ) -> OrbitParticipant? {
    participants.first { $0.id == id }
  }

  func activationRecord(
    for messageID: String
  ) -> OrbitActivationRecord? {
    activationRecords.first { $0.responseMessageID == messageID }
  }

  func activationContractSnapshot(
    for activationID: String
  ) -> OrbitActivationContractSnapshot? {
    activationContractSnapshots.first { $0.activationID == activationID }
  }

  func activationFailureRecord(
    for triggerMessageID: String
  ) -> OrbitActivationFailureRecord? {
    activationFailureRecords.first { $0.triggerMessageID == triggerMessageID }
  }

  func activationFailureRecordForSystemEvent(
    _ messageID: String
  ) -> OrbitActivationFailureRecord? {
    activationFailureRecords.first { $0.systemEventMessageID == messageID }
  }

  @discardableResult
  mutating func appendConversationTurn(
    body: String,
    addressedParticipantID: String?
  ) -> [OrbitMessage] {
    guard
      let threadIndex = threads.firstIndex(where: { $0.id == activeThreadID }),
      let triggerMessage = appendUserMessage(
        body: body,
        addressedParticipantID: addressedParticipantID
      )
    else {
      return []
    }

    let addressedParticipants = OrbitParticipantResponseBridge.addressedParticipants(
      in: self,
      addressedParticipantID: addressedParticipantID
    )
    let triggerSource = OrbitParticipantResponseBridge.triggerSource(
      for: addressedParticipantID
    )

    var createdMessages = [triggerMessage]

    if let activationFailure = evaluateActivationFailure(
      addressedParticipantID: addressedParticipantID,
      addressedParticipants: addressedParticipants,
      triggerSource: triggerSource,
      triggerMessageID: triggerMessage.id
    ) {
      if let systemEventMessage = appendSystemEvent(body: activationFailure.systemEventBody) {
        activationFailureRecords.append(
          OrbitActivationFailureRecord(
            id: activationFailure.id,
            workspaceID: activationFailure.workspaceID,
            addressedTargetID: activationFailure.addressedTargetID,
            participantID: activationFailure.participantID,
            workspacePersonaID: activationFailure.workspacePersonaID,
            personaTemplateID: activationFailure.personaTemplateID,
            directiveID: activationFailure.directiveID,
            triggerSource: activationFailure.triggerSource,
            triggerMessageID: activationFailure.triggerMessageID,
            systemEventMessageID: systemEventMessage.id,
            requiredSkillIDs: activationFailure.requiredSkillIDs,
            authorizedSkillIDs: activationFailure.authorizedSkillIDs,
            failureReason: activationFailure.failureReason,
            systemEventBody: activationFailure.systemEventBody
          )
        )
        createdMessages.append(systemEventMessage)
      }

      nextActivationFailureSequence += 1

      return createdMessages
    }

    threads[threadIndex].interactionMode =
      OrbitParticipantResponseBridge.interactionMode(for: addressedParticipantID)

    if let systemEventBody = OrbitParticipantResponseBridge.systemEventBody(
      for: addressedParticipants,
      triggerSource: triggerSource
    ), let systemEventMessage = appendSystemEvent(body: systemEventBody) {
      createdMessages.append(systemEventMessage)
    }

    for participant in addressedParticipants {
      guard
        let responseMessage = appendParticipantResponse(
          participant,
          triggerMessage: triggerMessage,
          triggerSource: triggerSource
        )
      else {
        continue
      }

      createdMessages.append(responseMessage)
    }

    return createdMessages
  }

  mutating func appendConversationTurnIfPersisted(
    body: String,
    addressedParticipantID: String?,
    persist: (OrbitWorkspace) throws -> Void
  ) throws -> [OrbitMessage] {
    var stagedWorkspace = self
    let createdMessages = stagedWorkspace.appendConversationTurn(
      body: body,
      addressedParticipantID: addressedParticipantID
    )

    try persist(stagedWorkspace)
    self = stagedWorkspace

    return createdMessages
  }

  @discardableResult
  mutating func appendUserMessage(
    body: String,
    addressedParticipantID: String?
  ) -> OrbitMessage? {
    guard let threadIndex = threads.firstIndex(where: { $0.id == activeThreadID }) else {
      return nil
    }

    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedBody.isEmpty else {
      return nil
    }

    let message = appendMessage(
      threadIndex: threadIndex,
      speakerParticipantID: OrbitParticipantID.aj.rawValue,
      addressedParticipantID: addressedParticipantID,
      body: trimmedBody,
      kind: .user
    )

    return message
  }

  static func messageID(
    for sequence: Int
  ) -> String {
    String(format: "msg-%04d", sequence)
  }

  static func activationID(
    for sequence: Int
  ) -> String {
    String(format: "act-%04d", sequence)
  }

  static func activationContractSnapshotID(
    for activationID: String
  ) -> String {
    "\(activationID)-contract"
  }

  static func activationFailureID(
    for sequence: Int
  ) -> String {
    String(format: "afail-%04d", sequence)
  }

  private func evaluateActivationFailure(
    addressedParticipantID: String?,
    addressedParticipants: [OrbitParticipant],
    triggerSource: OrbitActivationTriggerSource,
    triggerMessageID: String
  ) -> OrbitActivationFailureRecord? {
    if let addressedParticipantID,
      addressedParticipantID != OrbitAddressTargetID.foundingGroup.rawValue,
      addressedParticipants.isEmpty
    {
      return OrbitActivationFailureRecord(
        id: Self.activationFailureID(for: nextActivationFailureSequence),
        workspaceID: id,
        addressedTargetID: addressedParticipantID,
        participantID: nil,
        workspacePersonaID: nil,
        personaTemplateID: nil,
        directiveID: nil,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessageID,
        systemEventMessageID: nil,
        requiredSkillIDs: [],
        authorizedSkillIDs: [],
        failureReason: .unknownCollaboratorTarget,
        systemEventBody: "Orbit blocked the activation because the addressed collaborator could not be resolved in this workspace."
      )
    }

    for participant in addressedParticipants {
      if participant.id == OrbitParticipantID.prodDoc.rawValue,
        participant.personaTemplateID != "venture-product-steward"
      {
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: addressedParticipantID,
          participantID: participant.id,
          workspacePersonaID: participant.workspacePersonaID,
          personaTemplateID: participant.personaTemplateID,
          directiveID: participant.defaultDirectiveID,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: [],
          authorizedSkillIDs: [],
          failureReason: .frozenProdDocAliasContradiction,
          systemEventBody: "Orbit blocked the activation because the frozen ProdDoc identity mapping does not match venture-product-steward."
        )
      }

      if participant.workspacePersonaID == nil {
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: addressedParticipantID,
          participantID: participant.id,
          workspacePersonaID: nil,
          personaTemplateID: participant.personaTemplateID,
          directiveID: participant.defaultDirectiveID,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: [],
          authorizedSkillIDs: participant.authorizedSkillIDs,
          failureReason: .missingWorkspacePersona,
          systemEventBody: "Orbit blocked the activation because the collaborator is missing a stable workspace persona anchor."
        )
      }

      if participant.personaTemplateID == nil {
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: addressedParticipantID,
          participantID: participant.id,
          workspacePersonaID: participant.workspacePersonaID,
          personaTemplateID: nil,
          directiveID: participant.defaultDirectiveID,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: participant.requiredSkillIDs,
          authorizedSkillIDs: participant.authorizedSkillIDs,
          failureReason: .missingPersonaTemplate,
          systemEventBody: "Orbit blocked the activation because the collaborator is missing a PersonaKit persona-template mapping."
        )
      }

      if participant.defaultDirectiveID == nil {
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: addressedParticipantID,
          participantID: participant.id,
          workspacePersonaID: participant.workspacePersonaID,
          personaTemplateID: participant.personaTemplateID,
          directiveID: nil,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: participant.requiredSkillIDs,
          authorizedSkillIDs: participant.authorizedSkillIDs,
          failureReason: .missingDirective,
          systemEventBody: "Orbit blocked the activation because the collaborator has no resolved directive for this checkpoint."
        )
      }

      let unauthorizedRequiredSkills = participant.requiredSkillIDs.filter {
        !participant.authorizedSkillIDs.contains($0)
      }

      if !unauthorizedRequiredSkills.isEmpty {
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: addressedParticipantID,
          participantID: participant.id,
          workspacePersonaID: participant.workspacePersonaID,
          personaTemplateID: participant.personaTemplateID,
          directiveID: participant.defaultDirectiveID,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: participant.requiredSkillIDs,
          authorizedSkillIDs: participant.authorizedSkillIDs,
          failureReason: .unauthorizedSkillPosture,
          systemEventBody: "Orbit blocked the activation because the required skill posture is not authorized for this collaborator."
        )
      }
    }

    return nil
  }

  private mutating func appendParticipantResponse(
    _ participant: OrbitParticipant,
    triggerMessage: OrbitMessage,
    triggerSource: OrbitActivationTriggerSource
  ) -> OrbitMessage? {
    guard let threadIndex = threads.firstIndex(where: { $0.id == activeThreadID }) else {
      return nil
    }

    let responseMessage = appendMessage(
      threadIndex: threadIndex,
      speakerParticipantID: participant.id,
      addressedParticipantID: OrbitParticipantID.aj.rawValue,
      body: OrbitParticipantResponseBridge.responseBody(
        for: participant,
        triggerMessage: triggerMessage,
        triggerSource: triggerSource
      ),
      kind: .participantResponse
    )

    let activationID = Self.activationID(for: nextActivationSequence)
    let activationRecord = OrbitActivationRecord(
      id: activationID,
      workspaceID: id,
      responseMessageID: responseMessage.id,
      participantID: participant.id,
      workspacePersonaID: participant.workspacePersonaID,
      personaTemplateID: participant.personaTemplateID,
      directiveID: participant.defaultDirectiveID,
      responseMode: threads[threadIndex].interactionMode,
      triggerSource: triggerSource,
      triggerMessageID: triggerMessage.id,
      memoryInfluenced: false,
      memorySourceRefs: []
    )

    activationRecords.append(activationRecord)
    activationContractSnapshots.append(
      OrbitActivationContractSnapshot(
        id: Self.activationContractSnapshotID(for: activationID),
        activationID: activationID,
        directiveSource: .participantDefault,
        kitIDs: [],
        authorizedSkillIDs: participant.authorizedSkillIDs,
        stopPointIDs: [],
        reviewGateIDs: [],
        memoryScopeIDs: []
      )
    )
    nextActivationSequence += 1

    return responseMessage
  }

  private mutating func appendSystemEvent(
    body: String
  ) -> OrbitMessage? {
    guard let threadIndex = threads.firstIndex(where: { $0.id == activeThreadID }) else {
      return nil
    }

    return appendMessage(
      threadIndex: threadIndex,
      speakerParticipantID: OrbitParticipantID.samwise.rawValue,
      addressedParticipantID: nil,
      body: body,
      kind: .systemEvent
    )
  }

  private mutating func appendMessage(
    threadIndex: Int,
    speakerParticipantID: String,
    addressedParticipantID: String?,
    body: String,
    kind: OrbitMessageKind
  ) -> OrbitMessage {
    let nextOrder =
      (threads[threadIndex].messages.map(\.order).max() ?? 0)
      + 1
    let message = OrbitMessage(
      id: Self.messageID(for: nextMessageSequence),
      speakerParticipantID: speakerParticipantID,
      addressedParticipantID: addressedParticipantID,
      body: body,
      order: nextOrder,
      kind: kind
    )

    threads[threadIndex].messages.append(message)
    threads[threadIndex].updatedSequence = nextOrder
    nextMessageSequence += 1

    return message
  }
}

struct OrbitParticipant: Codable, Equatable, Identifiable {
  let id: String
  let workspacePersonaID: String?
  let displayName: String
  let roleLabel: String
  let participantType: OrbitParticipantType
  let personaTemplateID: String?
  let defaultDirectiveID: String?
  let requiredSkillIDs: [String]
  let authorizedSkillIDs: [String]
  let availability: OrbitParticipantAvailability
  let sortOrder: Int
}

enum OrbitParticipantType: String, Codable, Equatable {
  case human
  case ai
}

enum OrbitParticipantAvailability: String, Codable, Equatable {
  case active
  case available
  case idle

  var displayText: String {
    switch self {
    case .active:
      return "Active"
    case .available:
      return "Available"
    case .idle:
      return "Idle"
    }
  }
}

enum OrbitParticipantID: String {
  case aj
  case samwise
  case prodDoc = "proddoc"
}

enum OrbitAddressTargetID: String {
  case foundingGroup = "founding-group"

  var displayText: String {
    switch self {
    case .foundingGroup:
      return "Founding Group"
    }
  }
}

struct OrbitConversationThread: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var interactionMode: OrbitInteractionMode
  let createdSequence: Int
  var updatedSequence: Int
  var messages: [OrbitMessage]
}

enum OrbitInteractionMode: String, Codable, Equatable {
  case directMessage
  case lightweightMeeting

  var displayText: String {
    switch self {
    case .directMessage:
      return "Direct Message"
    case .lightweightMeeting:
      return "Lightweight Meeting"
    }
  }
}

struct OrbitMessage: Codable, Equatable, Identifiable {
  let id: String
  let speakerParticipantID: String
  let addressedParticipantID: String?
  let body: String
  let order: Int
  let kind: OrbitMessageKind
}

enum OrbitMessageKind: String, Codable, Equatable {
  case user
  case participantResponse
  case systemEvent

  var displayText: String {
    switch self {
    case .user:
      return "User"
    case .participantResponse:
      return "Participant"
    case .systemEvent:
      return "System"
    }
  }
}

struct OrbitActivationRecord: Codable, Equatable, Identifiable {
  let id: String
  let workspaceID: String?
  let responseMessageID: String
  let participantID: String
  let workspacePersonaID: String?
  let personaTemplateID: String?
  let directiveID: String?
  let responseMode: OrbitInteractionMode?
  let triggerSource: OrbitActivationTriggerSource
  let triggerMessageID: String?
  let memoryInfluenced: Bool
  let memorySourceRefs: [String]?

  func traceSummaryLines(
    contractSnapshot: OrbitActivationContractSnapshot?
  ) -> [String] {
    var lines = [
      "workspace persona: \(workspacePersonaID ?? "-") | persona template: \(personaTemplateID ?? "-")",
      "directive: \(directiveID ?? "-") | mode: \(responseMode?.displayText ?? "-") | memory: \(memoryInfluenced ? "used" : "none")",
    ]

    if let contractSnapshot {
      lines.append(contractSnapshot.summaryLine)
    }

    return lines
  }
}

struct OrbitActivationContractSnapshot: Codable, Equatable, Identifiable {
  let id: String
  let activationID: String
  let directiveSource: OrbitDirectiveSource
  let kitIDs: [String]
  let authorizedSkillIDs: [String]
  let stopPointIDs: [String]
  let reviewGateIDs: [String]
  let memoryScopeIDs: [String]

  var summaryLine: String {
    "contract: kits \(joinedSummary(for: kitIDs)) | skills \(joinedSummary(for: authorizedSkillIDs)) | stop points \(joinedSummary(for: stopPointIDs)) | review gates \(joinedSummary(for: reviewGateIDs)) | memory scopes \(joinedSummary(for: memoryScopeIDs))"
  }

  private func joinedSummary(
    for values: [String]
  ) -> String {
    values.isEmpty ? "none" : values.joined(separator: ", ")
  }
}

struct OrbitActivationFailureRecord: Codable, Equatable, Identifiable {
  let id: String
  let workspaceID: String?
  let addressedTargetID: String?
  let participantID: String?
  let workspacePersonaID: String?
  let personaTemplateID: String?
  let directiveID: String?
  let triggerSource: OrbitActivationTriggerSource
  let triggerMessageID: String?
  let systemEventMessageID: String?
  let requiredSkillIDs: [String]
  let authorizedSkillIDs: [String]
  let failureReason: OrbitActivationFailureReason
  let systemEventBody: String

  var traceSummaryLines: [String] {
    var lines = [
      "reason: \(failureReason.displayText)",
      "target: \(addressedTargetID ?? participantID ?? "-") | workspace persona: \(workspacePersonaID ?? "-") | persona template: \(personaTemplateID ?? "-")",
    ]

    if !requiredSkillIDs.isEmpty || !authorizedSkillIDs.isEmpty {
      let required = requiredSkillIDs.isEmpty ? "none" : requiredSkillIDs.joined(separator: ", ")
      let authorized = authorizedSkillIDs.isEmpty ? "none" : authorizedSkillIDs.joined(separator: ", ")
      lines.append("skills: required \(required) | authorized \(authorized)")
    }

    return lines
  }
}

extension OrbitActivationFailureRecord {
  private enum CodingKeys: String, CodingKey {
    case id
    case workspaceID
    case addressedTargetID
    case participantID
    case workspacePersonaID
    case personaTemplateID
    case directiveID
    case triggerSource
    case triggerMessageID
    case systemEventMessageID
    case requiredSkillIDs
    case authorizedSkillIDs
    case failureReason
    case systemEventBody
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    workspaceID = try container.decodeIfPresent(String.self, forKey: .workspaceID)
    addressedTargetID = try container.decodeIfPresent(String.self, forKey: .addressedTargetID)
    participantID = try container.decodeIfPresent(String.self, forKey: .participantID)
    workspacePersonaID = try container.decodeIfPresent(String.self, forKey: .workspacePersonaID)
    personaTemplateID = try container.decodeIfPresent(String.self, forKey: .personaTemplateID)
    directiveID = try container.decodeIfPresent(String.self, forKey: .directiveID)
    triggerSource = try container.decode(OrbitActivationTriggerSource.self, forKey: .triggerSource)
    triggerMessageID = try container.decodeIfPresent(String.self, forKey: .triggerMessageID)
    systemEventMessageID = try container.decodeIfPresent(String.self, forKey: .systemEventMessageID)
    requiredSkillIDs = try container.decodeIfPresent([String].self, forKey: .requiredSkillIDs) ?? []
    authorizedSkillIDs = try container.decodeIfPresent([String].self, forKey: .authorizedSkillIDs) ?? []
    failureReason = try container.decode(OrbitActivationFailureReason.self, forKey: .failureReason)
    systemEventBody = try container.decode(String.self, forKey: .systemEventBody)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(workspaceID, forKey: .workspaceID)
    try container.encodeIfPresent(addressedTargetID, forKey: .addressedTargetID)
    try container.encodeIfPresent(participantID, forKey: .participantID)
    try container.encodeIfPresent(workspacePersonaID, forKey: .workspacePersonaID)
    try container.encodeIfPresent(personaTemplateID, forKey: .personaTemplateID)
    try container.encodeIfPresent(directiveID, forKey: .directiveID)
    try container.encode(triggerSource, forKey: .triggerSource)
    try container.encodeIfPresent(triggerMessageID, forKey: .triggerMessageID)
    try container.encodeIfPresent(systemEventMessageID, forKey: .systemEventMessageID)
    try container.encode(requiredSkillIDs, forKey: .requiredSkillIDs)
    try container.encode(authorizedSkillIDs, forKey: .authorizedSkillIDs)
    try container.encode(failureReason, forKey: .failureReason)
    try container.encode(systemEventBody, forKey: .systemEventBody)
  }
}

enum OrbitDirectiveSource: String, Codable, Equatable {
  case participantDefault
}

enum OrbitActivationFailureReason: String, Codable, Equatable {
  case unknownCollaboratorTarget
  case missingWorkspacePersona
  case missingPersonaTemplate
  case frozenProdDocAliasContradiction
  case missingDirective
  case unauthorizedSkillPosture

  var displayText: String {
    switch self {
    case .unknownCollaboratorTarget:
      return "unknown collaborator target"
    case .missingWorkspacePersona:
      return "missing workspace persona"
    case .missingPersonaTemplate:
      return "missing persona template"
    case .frozenProdDocAliasContradiction:
      return "frozen ProdDoc alias contradiction"
    case .missingDirective:
      return "missing directive"
    case .unauthorizedSkillPosture:
      return "unauthorized skill posture"
    }
  }
}

enum OrbitActivationTriggerSource: String, Codable, Equatable {
  case directAddress
  case meetingInvocation
  case generalThreadReply
}

extension OrbitWorkspace {
  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case id
    case displayName
    case purpose
    case participants
    case activeThreadID
    case threads
    case activationRecords
    case activationContractSnapshots
    case activationFailureRecords
    case nextMessageSequence
    case nextActivationSequence
    case nextActivationFailureSequence
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1

    schemaVersion = max(decodedSchemaVersion, Self.currentSchemaVersion)
    let decodedWorkspaceID = try container.decode(String.self, forKey: .id)
    id = decodedWorkspaceID
    displayName = try container.decode(String.self, forKey: .displayName)
    purpose = try container.decode(String.self, forKey: .purpose)
    participants = try container.decode([OrbitParticipant].self, forKey: .participants)
    activeThreadID = try container.decode(String.self, forKey: .activeThreadID)
    let decodedThreads = try container.decode([OrbitConversationThread].self, forKey: .threads)
    threads = decodedThreads

    let participantMap = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
    let decodedActivationRecords = try container.decode([OrbitActivationRecord].self, forKey: .activationRecords)
    let normalizedActivationRecords = decodedActivationRecords.map { record in
      OrbitActivationRecord(
        id: record.id,
        workspaceID: record.workspaceID ?? decodedWorkspaceID,
        responseMessageID: record.responseMessageID,
        participantID: record.participantID,
        workspacePersonaID: record.workspacePersonaID ?? participantMap[record.participantID]?.workspacePersonaID,
        personaTemplateID: record.personaTemplateID ?? participantMap[record.participantID]?.personaTemplateID,
        directiveID: record.directiveID ?? participantMap[record.participantID]?.defaultDirectiveID,
        responseMode: record.responseMode ?? Self.interactionMode(for: record.responseMessageID, in: decodedThreads),
        triggerSource: record.triggerSource,
        triggerMessageID: record.triggerMessageID,
        memoryInfluenced: record.memoryInfluenced,
        memorySourceRefs: record.memorySourceRefs ?? []
      )
    }
    activationRecords = normalizedActivationRecords

    activationContractSnapshots =
      try container.decodeIfPresent([OrbitActivationContractSnapshot].self, forKey: .activationContractSnapshots)
      ?? normalizedActivationRecords.map(Self.scaffoldedContractSnapshot(for:))

    activationFailureRecords =
      try container.decodeIfPresent([OrbitActivationFailureRecord].self, forKey: .activationFailureRecords)
      ?? []

    nextMessageSequence = try container.decode(Int.self, forKey: .nextMessageSequence)
    nextActivationSequence = try container.decode(Int.self, forKey: .nextActivationSequence)
    nextActivationFailureSequence =
      try container.decodeIfPresent(Int.self, forKey: .nextActivationFailureSequence) ?? 1
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(id, forKey: .id)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(purpose, forKey: .purpose)
    try container.encode(participants, forKey: .participants)
    try container.encode(activeThreadID, forKey: .activeThreadID)
    try container.encode(threads, forKey: .threads)
    try container.encode(activationRecords, forKey: .activationRecords)
    try container.encode(activationContractSnapshots, forKey: .activationContractSnapshots)
    try container.encode(activationFailureRecords, forKey: .activationFailureRecords)
    try container.encode(nextMessageSequence, forKey: .nextMessageSequence)
    try container.encode(nextActivationSequence, forKey: .nextActivationSequence)
    try container.encode(nextActivationFailureSequence, forKey: .nextActivationFailureSequence)
  }

  private static func interactionMode(
    for responseMessageID: String,
    in threads: [OrbitConversationThread]
  ) -> OrbitInteractionMode? {
    threads.first { thread in
      thread.messages.contains { $0.id == responseMessageID }
    }?.interactionMode
  }

  private static func scaffoldedContractSnapshot(
    for activationRecord: OrbitActivationRecord
  ) -> OrbitActivationContractSnapshot {
    OrbitActivationContractSnapshot(
      id: activationContractSnapshotID(for: activationRecord.id),
      activationID: activationRecord.id,
      directiveSource: .participantDefault,
      kitIDs: [],
      authorizedSkillIDs: [],
      stopPointIDs: [],
      reviewGateIDs: [],
      memoryScopeIDs: []
    )
  }
}

extension OrbitParticipant {
  private enum CodingKeys: String, CodingKey {
    case id
    case workspacePersonaID
    case displayName
    case roleLabel
    case participantType
    case personaTemplateID
    case personaID
    case defaultDirectiveID
    case requiredSkillIDs
    case authorizedSkillIDs
    case availability
    case sortOrder
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    workspacePersonaID = try container.decodeIfPresent(String.self, forKey: .workspacePersonaID)
    displayName = try container.decode(String.self, forKey: .displayName)
    roleLabel = try container.decode(String.self, forKey: .roleLabel)
    participantType = try container.decode(OrbitParticipantType.self, forKey: .participantType)
    personaTemplateID =
      try container.decodeIfPresent(String.self, forKey: .personaTemplateID)
      ?? container.decodeIfPresent(String.self, forKey: .personaID)
    defaultDirectiveID = try container.decodeIfPresent(String.self, forKey: .defaultDirectiveID)
    requiredSkillIDs = try container.decodeIfPresent([String].self, forKey: .requiredSkillIDs) ?? []
    authorizedSkillIDs = try container.decodeIfPresent([String].self, forKey: .authorizedSkillIDs) ?? []
    availability = try container.decode(OrbitParticipantAvailability.self, forKey: .availability)
    sortOrder = try container.decode(Int.self, forKey: .sortOrder)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(workspacePersonaID, forKey: .workspacePersonaID)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(roleLabel, forKey: .roleLabel)
    try container.encode(participantType, forKey: .participantType)
    try container.encodeIfPresent(personaTemplateID, forKey: .personaTemplateID)
    try container.encodeIfPresent(defaultDirectiveID, forKey: .defaultDirectiveID)
    try container.encode(requiredSkillIDs, forKey: .requiredSkillIDs)
    try container.encode(authorizedSkillIDs, forKey: .authorizedSkillIDs)
    try container.encode(availability, forKey: .availability)
    try container.encode(sortOrder, forKey: .sortOrder)
  }
}

extension OrbitActivationRecord {
  private enum CodingKeys: String, CodingKey {
    case id
    case workspaceID
    case responseMessageID
    case participantID
    case workspacePersonaID
    case personaTemplateID
    case personaID
    case directiveID
    case responseMode
    case triggerSource
    case triggerMessageID
    case memoryInfluenced
    case memorySourceRefs
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    workspaceID = try container.decodeIfPresent(String.self, forKey: .workspaceID)
    responseMessageID = try container.decode(String.self, forKey: .responseMessageID)
    participantID = try container.decode(String.self, forKey: .participantID)
    workspacePersonaID = try container.decodeIfPresent(String.self, forKey: .workspacePersonaID)
    personaTemplateID =
      try container.decodeIfPresent(String.self, forKey: .personaTemplateID)
      ?? container.decodeIfPresent(String.self, forKey: .personaID)
    directiveID = try container.decodeIfPresent(String.self, forKey: .directiveID)
    responseMode = try container.decodeIfPresent(OrbitInteractionMode.self, forKey: .responseMode)
    triggerSource = try container.decode(OrbitActivationTriggerSource.self, forKey: .triggerSource)
    triggerMessageID = try container.decodeIfPresent(String.self, forKey: .triggerMessageID)
    memoryInfluenced = try container.decode(Bool.self, forKey: .memoryInfluenced)
    memorySourceRefs = try container.decodeIfPresent([String].self, forKey: .memorySourceRefs)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(workspaceID, forKey: .workspaceID)
    try container.encode(responseMessageID, forKey: .responseMessageID)
    try container.encode(participantID, forKey: .participantID)
    try container.encodeIfPresent(workspacePersonaID, forKey: .workspacePersonaID)
    try container.encodeIfPresent(personaTemplateID, forKey: .personaTemplateID)
    try container.encodeIfPresent(directiveID, forKey: .directiveID)
    try container.encodeIfPresent(responseMode, forKey: .responseMode)
    try container.encode(triggerSource, forKey: .triggerSource)
    try container.encodeIfPresent(triggerMessageID, forKey: .triggerMessageID)
    try container.encode(memoryInfluenced, forKey: .memoryInfluenced)
    try container.encodeIfPresent(memorySourceRefs, forKey: .memorySourceRefs)
  }
}
