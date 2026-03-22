import Foundation
import OrbitServerRuntime

struct OrbitWorkspace: Codable, Equatable {
  static let currentSchemaVersion = 6

  var schemaVersion = OrbitWorkspace.currentSchemaVersion
  var id: String
  var displayName: String
  var purpose: String
  var participants: [OrbitParticipant]
  var teams: [OrbitTeam] = []
  var squads: [OrbitSquad] = []
  var workspacePersonaMemberships: [OrbitWorkspacePersonaMembership] = []
  var activeThreadID: String
  var threads: [OrbitConversationThread]
  var activationRecords: [OrbitActivationRecord]
  var activationContractSnapshots: [OrbitActivationContractSnapshot]
  var activationFailureRecords: [OrbitActivationFailureRecord]
  var meetingPromotionRecords: [OrbitMeetingPromotionRecord]
  var meetingContinuityRecords: [OrbitMeetingContinuityRecord]
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

  func participant(
    workspacePersonaID: String
  ) -> OrbitParticipant? {
    participants.first { $0.workspacePersonaID == workspacePersonaID }
  }

  func team(
    slug: String
  ) -> OrbitTeam? {
    teams.first { $0.slug == slug }
  }

  func squad(
    slug: String
  ) -> OrbitSquad? {
    squads.first { $0.slug == slug }
  }

  func displayName(
    forAddressedTargetID addressedTargetID: String
  ) -> String? {
    if let team = team(slug: addressedTargetID) {
      return team.name
    }

    if let squad = squad(slug: addressedTargetID) {
      return squad.name
    }

    return participant(id: addressedTargetID)?.displayName
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

  func activationFailureRecords(
    for triggerMessageID: String
  ) -> [OrbitActivationFailureRecord] {
    activationFailureRecords.filter { $0.triggerMessageID == triggerMessageID }
  }

  func activationFailureRecordForSystemEvent(
    _ messageID: String
  ) -> OrbitActivationFailureRecord? {
    activationFailureRecords.first { $0.systemEventMessageID == messageID }
  }

  func meetingPromotionFailureRecordForSystemEvent(
    _ messageID: String
  ) -> OrbitMeetingPromotionRecord? {
    meetingPromotionRecords.first {
      $0.outcome == .failed && $0.systemEventMessageID == messageID
    }
  }

  @discardableResult
  mutating func appendConversationTurn(
    body: String,
    addressedParticipantID: String?
  ) -> [OrbitMessage] {
    let addressedParticipants = OrbitParticipantResponseBridge.addressedParticipants(
      in: self,
      addressedParticipantID: addressedParticipantID
    )
    let resolvedContractsByParticipantID = Dictionary(uniqueKeysWithValues: addressedParticipants.map {
      ($0.id, Self.scaffoldedActivationContract(for: $0))
    })

    return appendConversationTurn(
      body: body,
      addressedParticipantID: addressedParticipantID,
      resolvedContractsByParticipantID: resolvedContractsByParticipantID
    )
  }

  @discardableResult
  private mutating func appendConversationTurn(
    body: String,
    addressedParticipantID: String?,
    resolvedContractsByParticipantID: [String: OrbitResolvedActivationContract]
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

    let targetResolution = addressedParticipantID.flatMap { addressedParticipantID in
      OrbitParticipantResponseBridge.targetResolution(
        in: self,
        addressedParticipantID: addressedParticipantID
      )
    }
    let addressedParticipants =
      targetResolution?.includedParticipants
      ?? OrbitParticipantResponseBridge.addressedParticipants(
        in: self,
        addressedParticipantID: addressedParticipantID
      )
    let triggerSource = OrbitParticipantResponseBridge.triggerSource(
      in: self,
      addressedParticipantID: addressedParticipantID
    )

    var createdMessages = [triggerMessage]

    if let activationFailure = preExchangeActivationFailure(
      addressedParticipantID: addressedParticipantID,
      targetResolution: targetResolution,
      addressedParticipants: addressedParticipants,
      triggerSource: triggerSource,
      triggerMessageID: triggerMessage.id
    ) {
      if let systemEventMessage = appendActivationFailure(activationFailure) {
        createdMessages.append(systemEventMessage)
      }

      return createdMessages
    }

    threads[threadIndex].interactionMode =
      OrbitParticipantResponseBridge.interactionMode(
        in: self,
        addressedParticipantID: addressedParticipantID
      )

    if let systemEventBody = OrbitParticipantResponseBridge.systemEventBody(
      for: targetResolution,
      in: self
    ), let systemEventMessage = appendSystemEvent(body: systemEventBody) {
      createdMessages.append(systemEventMessage)
    }

    var repliedParticipantIDs = Set<String>()
    var failedParticipantIDs = Set<String>()

    for participant in addressedParticipants {
      let resolvedContract =
        resolvedContractsByParticipantID[participant.id]
        ?? Self.scaffoldedActivationContract(for: participant)

      if let activationFailure = participantActivationFailure(
        participant: participant,
        addressedParticipantID: addressedParticipantID,
        targetResolution: targetResolution,
        resolvedContract: resolvedContract,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessage.id
      ) {
        failedParticipantIDs.insert(participant.id)

        if let systemEventMessage = appendActivationFailure(activationFailure) {
          createdMessages.append(systemEventMessage)
        }

        continue
      }

      guard
        let responseMessage = appendParticipantResponse(
          participant,
          resolvedContract: resolvedContract,
          triggerMessage: triggerMessage,
          triggerSource: triggerSource
        )
      else {
        continue
      }

      repliedParticipantIDs.insert(participant.id)
      createdMessages.append(responseMessage)
    }

    if let exchangeStateBody = OrbitParticipantResponseBridge.exchangeStateSystemEventBody(
      for: targetResolution,
      in: self,
      repliedParticipantIDs: repliedParticipantIDs,
      failedParticipantIDs: failedParticipantIDs
    ), let systemEventMessage = appendSystemEvent(body: exchangeStateBody) {
      createdMessages.append(systemEventMessage)
    }

    return createdMessages
  }

  mutating func appendConversationTurnIfPersisted(
    body: String,
    addressedParticipantID: String?,
    resolveContract: ((OrbitParticipant) throws -> OrbitResolvedActivationContract)? = nil,
    persist: (OrbitWorkspace) throws -> Void
  ) throws -> [OrbitMessage] {
    var stagedWorkspace = self
    let resolvedContractsByParticipantID = try stagedWorkspace.resolveActivationContracts(
      addressedParticipantID: addressedParticipantID,
      resolveContract: resolveContract
    )
    let createdMessages = stagedWorkspace.appendConversationTurn(
      body: body,
      addressedParticipantID: addressedParticipantID,
      resolvedContractsByParticipantID: resolvedContractsByParticipantID
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

  private func preExchangeActivationFailure(
    addressedParticipantID: String?,
    targetResolution: OrbitTargetResolution?,
    addressedParticipants: [OrbitParticipant],
    triggerSource: OrbitActivationTriggerSource,
    triggerMessageID: String
  ) -> OrbitActivationFailureRecord? {
    if let targetResolution {
      switch targetResolution.status {
      case .blocked:
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: targetResolution.targetReferenceID,
          participantID: nil,
          workspacePersonaID: nil,
          personaTemplateID: nil,
          directiveID: nil,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: [],
          authorizedSkillIDs: [],
          failureReason: .missingOrAmbiguousTarget,
          systemEventBody:
            OrbitParticipantResponseBridge.systemEventBody(for: targetResolution)
            ?? targetResolution.outcomeExplanation
            ?? "Orbit blocked the activation because the addressed target could not be resolved in this workspace."
        )
      case .empty:
        return OrbitActivationFailureRecord(
          id: Self.activationFailureID(for: nextActivationFailureSequence),
          workspaceID: id,
          addressedTargetID: targetResolution.targetReferenceID,
          participantID: nil,
          workspacePersonaID: nil,
          personaTemplateID: nil,
          directiveID: nil,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID,
          systemEventMessageID: nil,
          requiredSkillIDs: [],
          authorizedSkillIDs: [],
          failureReason: .emptyGroup,
          systemEventBody:
            OrbitParticipantResponseBridge.systemEventBody(for: targetResolution)
            ?? targetResolution.outcomeExplanation
            ?? "Orbit found no eligible workspace persona members for the addressed target."
        )
      case .resolved:
        break
      }
    } else if let addressedParticipantID, addressedParticipants.isEmpty {
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

    return nil
  }

  private func participantActivationFailure(
    participant: OrbitParticipant,
    addressedParticipantID: String?,
    targetResolution: OrbitTargetResolution?,
    resolvedContract: OrbitResolvedActivationContract,
    triggerSource: OrbitActivationTriggerSource,
    triggerMessageID: String
  ) -> OrbitActivationFailureRecord? {
    if participant.id == OrbitParticipantID.prodDoc.rawValue,
      participant.personaTemplateID != "venture-product-steward"
    {
      let detail =
        "Orbit blocked the activation because the frozen ProdDoc identity mapping does not match venture-product-steward."
      return OrbitActivationFailureRecord(
        id: Self.activationFailureID(for: nextActivationFailureSequence),
        workspaceID: id,
        addressedTargetID: addressedParticipantID,
        participantID: participant.id,
        workspacePersonaID: participant.workspacePersonaID,
        personaTemplateID: participant.personaTemplateID,
        directiveID: resolvedContract.directiveID,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessageID,
        systemEventMessageID: nil,
        requiredSkillIDs: resolvedContract.requiredSkillIDs,
        authorizedSkillIDs: resolvedContract.authorizedSkillIDs,
        failureReason: .frozenProdDocAliasContradiction,
        systemEventBody: failureSystemEventBody(
          targetResolution: targetResolution,
          detail: detail
        )
      )
    }

    if participant.workspacePersonaID == nil {
      let detail =
        "Orbit blocked the activation because the collaborator is missing a stable workspace persona anchor."
      return OrbitActivationFailureRecord(
        id: Self.activationFailureID(for: nextActivationFailureSequence),
        workspaceID: id,
        addressedTargetID: addressedParticipantID,
        participantID: participant.id,
        workspacePersonaID: nil,
        personaTemplateID: participant.personaTemplateID,
        directiveID: resolvedContract.directiveID,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessageID,
        systemEventMessageID: nil,
        requiredSkillIDs: resolvedContract.requiredSkillIDs,
        authorizedSkillIDs: resolvedContract.authorizedSkillIDs,
        failureReason: .missingWorkspacePersona,
        systemEventBody: failureSystemEventBody(
          targetResolution: targetResolution,
          detail: detail
        )
      )
    }

    if participant.personaTemplateID == nil {
      let detail =
        "Orbit blocked the activation because the collaborator is missing a PersonaKit persona-template mapping."
      return OrbitActivationFailureRecord(
        id: Self.activationFailureID(for: nextActivationFailureSequence),
        workspaceID: id,
        addressedTargetID: addressedParticipantID,
        participantID: participant.id,
        workspacePersonaID: participant.workspacePersonaID,
        personaTemplateID: nil,
        directiveID: resolvedContract.directiveID,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessageID,
        systemEventMessageID: nil,
        requiredSkillIDs: resolvedContract.requiredSkillIDs,
        authorizedSkillIDs: resolvedContract.authorizedSkillIDs,
        failureReason: .missingPersonaTemplate,
        systemEventBody: failureSystemEventBody(
          targetResolution: targetResolution,
          detail: detail
        )
      )
    }

    if resolvedContract.directiveID == nil {
      let detail =
        "Orbit blocked the activation because the collaborator has no resolved directive for this checkpoint."
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
        requiredSkillIDs: resolvedContract.requiredSkillIDs,
        authorizedSkillIDs: resolvedContract.authorizedSkillIDs,
        failureReason: .missingDirective,
        systemEventBody: failureSystemEventBody(
          targetResolution: targetResolution,
          detail: detail
        )
      )
    }

    let unauthorizedRequiredSkills = resolvedContract.unauthorizedRequiredSkillIDs

    if !unauthorizedRequiredSkills.isEmpty || !resolvedContract.failureReasons.isEmpty {
      let failureDetail = resolvedContract.failureReasons.first
        ?? "the required skill posture is not authorized for this collaborator"
      let detail = "Orbit blocked the activation because \(failureDetail)."
      return OrbitActivationFailureRecord(
        id: Self.activationFailureID(for: nextActivationFailureSequence),
        workspaceID: id,
        addressedTargetID: addressedParticipantID,
        participantID: participant.id,
        workspacePersonaID: participant.workspacePersonaID,
        personaTemplateID: participant.personaTemplateID,
        directiveID: resolvedContract.directiveID,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessageID,
        systemEventMessageID: nil,
        requiredSkillIDs: resolvedContract.requiredSkillIDs,
        authorizedSkillIDs: resolvedContract.authorizedSkillIDs,
        failureReason: .unauthorizedSkillPosture,
        systemEventBody: failureSystemEventBody(
          targetResolution: targetResolution,
          detail: detail
        )
      )
    }

    return nil
  }

  private mutating func appendParticipantResponse(
    _ participant: OrbitParticipant,
    resolvedContract: OrbitResolvedActivationContract,
    triggerMessage: OrbitMessage,
    triggerSource: OrbitActivationTriggerSource
  ) -> OrbitMessage? {
    guard let threadIndex = threads.firstIndex(where: { $0.id == activeThreadID }) else {
      return nil
    }

    let responseAddressedParticipantID =
      triggerSource == .directAddress
      ? OrbitParticipantID.aj.rawValue
      : (triggerMessage.addressedParticipantID ?? OrbitParticipantID.aj.rawValue)

    let responseMessage = appendMessage(
      threadIndex: threadIndex,
      speakerParticipantID: participant.id,
      addressedParticipantID: responseAddressedParticipantID,
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
      directiveID: resolvedContract.directiveID,
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
        directiveSource: resolvedContract.directiveSource,
        kitIDs: resolvedContract.kitIDs,
        authorizedSkillIDs: resolvedContract.authorizedSkillIDs,
        stopPointIDs: resolvedContract.stopPointIDs,
        reviewGateIDs: resolvedContract.reviewGateIDs,
        memoryScopeIDs: resolvedContract.memoryScopeIDs
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

  private func resolveActivationContracts(
    addressedParticipantID: String?,
    resolveContract: ((OrbitParticipant) throws -> OrbitResolvedActivationContract)?
  ) throws -> [String: OrbitResolvedActivationContract] {
    let addressedParticipants = OrbitParticipantResponseBridge.addressedParticipants(
      in: self,
      addressedParticipantID: addressedParticipantID
    )

    if let resolveContract {
      return try Dictionary(uniqueKeysWithValues: addressedParticipants.map { participant in
        (participant.id, try resolveContract(participant))
      })
    }

    return Dictionary(uniqueKeysWithValues: addressedParticipants.map { participant in
      (participant.id, Self.scaffoldedActivationContract(for: participant))
    })
  }

  private static func scaffoldedActivationContract(
    for participant: OrbitParticipant
  ) -> OrbitResolvedActivationContract {
    OrbitResolvedActivationContract(
      directiveID: participant.defaultDirectiveID,
      directiveSource: .participantDefault,
      kitIDs: [],
      authorizedSkillIDs: participant.authorizedSkillIDs,
      requiredSkillIDs: participant.requiredSkillIDs,
      stopPointIDs: [],
      reviewGateIDs: [],
      memoryScopeIDs: [],
      failureReasons: []
    )
  }

  private func failureSystemEventBody(
    targetResolution: OrbitTargetResolution?,
    detail: String
  ) -> String {
    guard let summary = OrbitParticipantResponseBridge.systemEventBody(for: targetResolution) else {
      return detail
    }

    return [summary, detail].joined(separator: "\n")
  }

  @discardableResult
  private mutating func appendActivationFailure(
    _ activationFailure: OrbitActivationFailureRecord
  ) -> OrbitMessage? {
    guard let systemEventMessage = appendSystemEvent(body: activationFailure.systemEventBody) else {
      return nil
    }

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
    nextActivationFailureSequence += 1

    return systemEventMessage
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

struct OrbitTeam: Codable, Equatable, Identifiable {
  let id: String
  let workspaceID: String
  let slug: String
  let name: String
  let purpose: String
  let createdAt: Date
}

struct OrbitSquad: Codable, Equatable, Identifiable {
  let id: String
  let workspaceID: String
  let teamID: String?
  let slug: String
  let name: String
  let purpose: String
  let createdAt: Date
}

struct OrbitWorkspacePersonaMembership: Codable, Equatable, Identifiable {
  let id: String
  let workspacePersonaID: String
  let teamID: String?
  let squadID: String?
  let roleInGroup: String
  let createdAt: Date
}

struct OrbitResolvedActivationContract: Equatable {
  let directiveID: String?
  let directiveSource: OrbitDirectiveSource
  let kitIDs: [String]
  let authorizedSkillIDs: [String]
  let requiredSkillIDs: [String]
  let stopPointIDs: [String]
  let reviewGateIDs: [String]
  let memoryScopeIDs: [String]
  let failureReasons: [String]

  var unauthorizedRequiredSkillIDs: [String] {
    requiredSkillIDs.filter { !authorizedSkillIDs.contains($0) }
  }
}

struct OrbitTargetResolution: Equatable {
  let status: OrbitTargetResolutionStatus
  let targetKind: OrbitAddressedTargetKind
  let targetReferenceID: String
  let targetDisplayName: String
  let workspaceID: String
  let includedParticipants: [OrbitParticipant]
  let includedParticipantReasons: [OrbitTargetParticipantReason]
  let excludedParticipantReasons: [OrbitTargetParticipantReason]
  let outcomeReasonCategory: OrbitTargetReasonCategory?
  let outcomeExplanation: String?
}

struct OrbitTargetParticipantReason: Equatable {
  let participantID: String?
  let workspacePersonaID: String?
  let displayName: String
  let reasonCategory: OrbitTargetReasonCategory
  let sourceTargetKind: OrbitAddressedTargetKind
  let sourceTargetReferenceID: String
  let explanation: String
}

enum OrbitTargetResolutionStatus: String, Equatable {
  case resolved
  case blocked
  case empty
}

enum OrbitTargetReasonCategory: String, Equatable {
  case directTarget = "direct_target"
  case teamMembership = "team_membership"
  case squadMembership = "squad_membership"
  case personaUnavailable = "persona_unavailable"
  case membershipUnresolved = "membership_unresolved"
  case missingOrAmbiguousTarget = "missing_or_ambiguous_target"
  case emptyGroup = "empty_group"
}

enum OrbitGroupParticipantRole: String, Equatable {
  case contributor
  case reviewer
}

enum OrbitGroupParticipantState: String, Equatable {
  case pending
  case replied
  case failed
}

enum OrbitGroupExchangeState: String, Equatable {
  case active
  case completed
  case partial
  case failed
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

struct OrbitMeetingPromotionRecord: Codable, Equatable, Identifiable {
  enum Outcome: String, Codable, Equatable {
    case attempted
    case failed
  }

  let id: String
  let workspaceID: String?
  let initiatedByParticipantID: String
  let addressedTargetKind: OrbitAddressedTargetKind
  let addressedTargetReferenceID: String
  let targetDisplayName: String
  let meetingType: OrbitMeetingType
  let title: String
  let memberWorkspacePersonaIDs: [String]
  let outcome: Outcome
  let systemEventMessageID: String?
  let systemEventBody: String?
  let detail: String?

  var traceSummaryLines: [String] {
    var lines = [
      "target: \(addressedTargetKind.rawValue) \(addressedTargetReferenceID) | title: \(title)",
      "meeting type: \(meetingType.rawValue) | initiated by: \(initiatedByParticipantID)",
      "members: \(memberWorkspacePersonaIDs.isEmpty ? "none" : memberWorkspacePersonaIDs.joined(separator: ", "))",
    ]

    if let detail {
      lines.append("detail: \(detail)")
    }

    return lines
  }
}

struct OrbitMeetingContinuityRecord: Codable, Equatable, Identifiable {
  enum Perspective: String, Codable, Equatable {
    case originThread = "origin_thread"
    case promotedMeeting = "promoted_meeting"
  }

  let id: String
  let currentPerspective: Perspective
  let originPostID: String
  let promotedMeetingPostID: String

  var currentPostID: String {
    currentPerspective == .originThread ? originPostID : promotedMeetingPostID
  }

  var linkedPostID: String {
    currentPerspective == .originThread ? promotedMeetingPostID : originPostID
  }
}

enum OrbitDirectiveSource: String, Codable, Equatable {
  case participantDefault
}

enum OrbitActivationFailureReason: String, Codable, Equatable {
  case unknownCollaboratorTarget
  case missingOrAmbiguousTarget
  case emptyGroup
  case missingWorkspacePersona
  case missingPersonaTemplate
  case frozenProdDocAliasContradiction
  case missingDirective
  case unauthorizedSkillPosture

  var displayText: String {
    switch self {
    case .unknownCollaboratorTarget:
      return "unknown collaborator target"
    case .missingOrAmbiguousTarget:
      return "missing or ambiguous target"
    case .emptyGroup:
      return "empty group"
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

  var displayText: String {
    switch self {
    case .directAddress:
      return "Direct Address"
    case .meetingInvocation:
      return "Lightweight Meeting"
    case .generalThreadReply:
      return "Current Thread"
    }
  }
}

extension OrbitWorkspace {
  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case id
    case displayName
    case purpose
    case participants
    case teams
    case squads
    case workspacePersonaMemberships
    case activeThreadID
    case threads
    case activationRecords
    case activationContractSnapshots
    case activationFailureRecords
    case meetingPromotionRecords
    case meetingContinuityRecords
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
    teams = try container.decodeIfPresent([OrbitTeam].self, forKey: .teams) ?? []
    squads = try container.decodeIfPresent([OrbitSquad].self, forKey: .squads) ?? []
    workspacePersonaMemberships =
      try container.decodeIfPresent(
        [OrbitWorkspacePersonaMembership].self,
        forKey: .workspacePersonaMemberships
      ) ?? []
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
    meetingPromotionRecords =
      try container.decodeIfPresent([OrbitMeetingPromotionRecord].self, forKey: .meetingPromotionRecords)
      ?? []
    meetingContinuityRecords =
      try container.decodeIfPresent([OrbitMeetingContinuityRecord].self, forKey: .meetingContinuityRecords)
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
    try container.encode(teams, forKey: .teams)
    try container.encode(squads, forKey: .squads)
    try container.encode(workspacePersonaMemberships, forKey: .workspacePersonaMemberships)
    try container.encode(activeThreadID, forKey: .activeThreadID)
    try container.encode(threads, forKey: .threads)
    try container.encode(activationRecords, forKey: .activationRecords)
    try container.encode(activationContractSnapshots, forKey: .activationContractSnapshots)
    try container.encode(activationFailureRecords, forKey: .activationFailureRecords)
    try container.encode(meetingPromotionRecords, forKey: .meetingPromotionRecords)
    try container.encode(meetingContinuityRecords, forKey: .meetingContinuityRecords)
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
