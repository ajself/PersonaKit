import Foundation
import OrbitServerRuntime

enum OrbitServerBackedRoomCoordinatorError: LocalizedError, Equatable {
  case projectedWorkspaceUnavailable
  case collaboratorWorkspacePersonaMissing(String)
  case preflightUserMessageUnavailable
  case preflightActivationRecordUnavailable(String)
  case preflightContractSnapshotUnavailable(String)
  case preflightActivationFailureUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .projectedWorkspaceUnavailable:
      return "Load the canonical Orbit room before sending collaborator-targeted turns."
    case .collaboratorWorkspacePersonaMissing(let participantID):
      return "Orbit could not map \(participantID) to a canonical workspace persona."
    case .preflightUserMessageUnavailable:
      return "Orbit could not stage the next canonical user turn."
    case .preflightActivationRecordUnavailable(let responseMessageID):
      return "Orbit could not recover staged activation evidence for \(responseMessageID)."
    case .preflightContractSnapshotUnavailable(let activationID):
      return "Orbit could not recover staged contract evidence for \(activationID)."
    case .preflightActivationFailureUnavailable(let triggerMessageID):
      return "Orbit could not recover staged activation-failure evidence for \(triggerMessageID)."
    }
  }
}

private struct OrbitServerBackedPreflightConversationTurn {
  let workspace: OrbitWorkspace
  let resolvedContractsByParticipantID: [String: OrbitResolvedActivationContract]
  let userMessage: OrbitMessage
  let systemEventMessage: OrbitMessage?
  let responseMessages: [OrbitMessage]
  let activationFailure: OrbitActivationFailureRecord?
}

struct OrbitServerBackedRoomCoordinator {
  private(set) var roomState = OrbitServerBackedRoomState()

  mutating func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    transport: some OrbitPhase1RealtimeTransportServing
  ) async throws {
    let response = try await transport.connect(
      request: OrbitPhase1RealtimeConnectRequest(scope: scope)
    )

    try roomState.apply(response)
  }

  mutating func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    client: OrbitServerBackedRoomClient
  ) async throws {
    let response = try await client.connect(scope: scope)
    try roomState.apply(response)
  }

  mutating func poll(
    transport: some OrbitPhase1RealtimeTransportServing
  ) async throws {
    guard let session = roomState.session else {
      return
    }

    let response = try await transport.poll(
      request: OrbitPhase1RealtimePollRequest(session: session)
    )

    try roomState.apply(response)
  }

  mutating func poll(
    client: OrbitServerBackedRoomClient
  ) async throws {
    guard let session = roomState.session else {
      return
    }

    let response = try await client.poll(session: session)
    try roomState.apply(response)
  }

  mutating func appendUserMessage(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    authorID: String,
    body: String,
    client: OrbitServerBackedRoomClient
  ) async throws {
    _ = try await client.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: scope.workspaceSlug,
        channelSlug: scope.channelSlug,
        authorID: authorID,
        body: body
      )
    )

    try await connect(scope: scope, client: client)
  }

  @MainActor
  mutating func appendConversationTurn(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    authorID: String,
    body: String,
    addressedParticipantID: String?,
    resolveContract: ((OrbitParticipant) throws -> OrbitResolvedActivationContract)? = nil,
    client: OrbitServerBackedRoomClient
  ) async throws {
    guard let projectedWorkspace = roomState.projectedWorkspace else {
      throw OrbitServerBackedRoomCoordinatorError.projectedWorkspaceUnavailable
    }

    let preflight = try preflightConversationTurn(
      in: projectedWorkspace,
      body: body,
      addressedParticipantID: addressedParticipantID,
      resolveContract: resolveContract
    )
    let appendResult = try await client.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: scope.workspaceSlug,
        channelSlug: scope.channelSlug,
        authorID: authorID,
        body: body
      )
    )

    do {
      if let activationFailure = preflight.activationFailure {
        let systemEventMessageID = UUID()

        _ = try await client.appendActivationFailure(
          OrbitPhase1AppendActivationFailureRequest(
            workspaceSlug: scope.workspaceSlug,
            channelSlug: scope.channelSlug,
            initiatedByParticipantID: authorID,
            triggerMessageID: appendResult.message.id,
            failure: failurePayload(
              from: activationFailure,
              systemEventMessageID: systemEventMessageID
            )
          )
        )
      } else {
        if let systemEventMessage = preflight.systemEventMessage {
          _ = try await client.appendSystemMessage(
            OrbitPhase1AppendSystemMessageRequest(
              workspaceSlug: scope.workspaceSlug,
              channelSlug: scope.channelSlug,
              body: systemEventMessage.body,
              replyToMessageID: appendResult.message.id
            )
          )
        }

        for responseMessage in preflight.responseMessages {
          let activation = try activationRecord(
            for: responseMessage,
            in: preflight.workspace
          )
          let contractSnapshot = try contractSnapshot(
            for: activation,
            in: preflight.workspace
          )
          let participant = try participant(
            id: activation.participantID,
            in: preflight.workspace
          )

          guard
            let workspacePersonaIDString = participant.workspacePersonaID,
            let workspacePersonaID = UUID(uuidString: workspacePersonaIDString)
          else {
            throw OrbitServerBackedRoomCoordinatorError.collaboratorWorkspacePersonaMissing(
              participant.id
            )
          }

          _ = try await client.appendCollaboratorResponse(
            OrbitPhase1AppendCollaboratorResponseRequest(
              workspaceSlug: scope.workspaceSlug,
              channelSlug: scope.channelSlug,
              workspacePersonaID: workspacePersonaID,
              initiatedByParticipantID: authorID,
              triggerMessageID: appendResult.message.id,
              addressedTargetKind: addressedTargetKind(
                for: addressedParticipantID
              ),
              addressedTargetReferenceID: addressedTargetReferenceID(
                for: participant,
                addressedParticipantID: addressedParticipantID
              ),
              responseMode: responseMode(
                for: addressedParticipantID
              ),
              body: responseMessage.body,
              contract: contractPayload(
                activation: activation,
                contractSnapshot: contractSnapshot,
                resolvedContract: preflight.resolvedContractsByParticipantID[activation.participantID]
              )
            )
          )
        }
      }

      try await connect(scope: scope, client: client)
    } catch {
      try? await connect(scope: scope, client: client)
      throw error
    }
  }

  private func responseMode(
    for addressedParticipantID: String?
  ) -> OrbitCanonicalResponseMode {
    switch addressedParticipantID {
    case nil:
      return .currentThread
    case OrbitAddressTargetID.foundingGroup.rawValue:
      return .lightweightMeeting
    default:
      return .directAddress
    }
  }

  private func addressedTargetKind(
    for addressedParticipantID: String?
  ) -> OrbitAddressedTargetKind {
    addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue
      ? .team
      : .collaborator
  }

  private func addressedTargetReferenceID(
    for participant: OrbitParticipant,
    addressedParticipantID: String?
  ) -> String {
    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return OrbitAddressTargetID.foundingGroup.rawValue
    }

    return participant.workspacePersonaID ?? participant.id
  }

  private func preflightConversationTurn(
    in projectedWorkspace: OrbitWorkspace,
    body: String,
    addressedParticipantID: String?,
    resolveContract: ((OrbitParticipant) throws -> OrbitResolvedActivationContract)? = nil
  ) throws -> OrbitServerBackedPreflightConversationTurn {
    var stagedWorkspace = projectedWorkspace
    var resolvedContractsByParticipantID = [String: OrbitResolvedActivationContract]()

    let createdMessages = try stagedWorkspace.appendConversationTurnIfPersisted(
      body: body,
      addressedParticipantID: addressedParticipantID,
      resolveContract: { participant in
        let resolvedContract =
          try resolveContract?(participant)
          ?? scaffoldedContract(for: participant)
        resolvedContractsByParticipantID[participant.id] = resolvedContract
        return resolvedContract
      },
      persist: { _ in }
    )

    guard let userMessage = createdMessages.first(where: { $0.kind == .user }) else {
      throw OrbitServerBackedRoomCoordinatorError.preflightUserMessageUnavailable
    }

    return OrbitServerBackedPreflightConversationTurn(
      workspace: stagedWorkspace,
      resolvedContractsByParticipantID: resolvedContractsByParticipantID,
      userMessage: userMessage,
      systemEventMessage: createdMessages.first(where: { $0.kind == .systemEvent }),
      responseMessages: createdMessages.filter { $0.kind == .participantResponse },
      activationFailure: stagedWorkspace.activationFailureRecord(for: userMessage.id)
    )
  }

  private func activationRecord(
    for responseMessage: OrbitMessage,
    in workspace: OrbitWorkspace
  ) throws -> OrbitActivationRecord {
    guard let activation = workspace.activationRecord(for: responseMessage.id) else {
      throw OrbitServerBackedRoomCoordinatorError.preflightActivationRecordUnavailable(
        responseMessage.id
      )
    }

    return activation
  }

  private func contractSnapshot(
    for activation: OrbitActivationRecord,
    in workspace: OrbitWorkspace
  ) throws -> OrbitActivationContractSnapshot {
    guard let contractSnapshot = workspace.activationContractSnapshot(for: activation.id) else {
      throw OrbitServerBackedRoomCoordinatorError.preflightContractSnapshotUnavailable(
        activation.id
      )
    }

    return contractSnapshot
  }

  private func participant(
    id: String,
    in workspace: OrbitWorkspace
  ) throws -> OrbitParticipant {
    guard let participant = workspace.participant(id: id) else {
      throw OrbitServerBackedRoomCoordinatorError.collaboratorWorkspacePersonaMissing(id)
    }

    return participant
  }

  private func contractPayload(
    activation: OrbitActivationRecord,
    contractSnapshot: OrbitActivationContractSnapshot,
    resolvedContract: OrbitResolvedActivationContract?
  ) -> OrbitPhase1ResolvedContractPayload {
    OrbitPhase1ResolvedContractPayload(
      directiveID: activation.directiveID,
      directiveSource: contractSnapshot.directiveSource.rawValue,
      kitIDs: contractSnapshot.kitIDs,
      authorizedSkillIDs: contractSnapshot.authorizedSkillIDs,
      requiredSkillIDs: resolvedContract?.requiredSkillIDs ?? [],
      stopPointIDs: contractSnapshot.stopPointIDs,
      reviewGateIDs: contractSnapshot.reviewGateIDs,
      memoryScopeIDs: contractSnapshot.memoryScopeIDs
    )
  }

  private func failurePayload(
    from failure: OrbitActivationFailureRecord,
    systemEventMessageID: UUID
  ) -> OrbitPhase1ActivationFailurePayload {
    OrbitPhase1ActivationFailurePayload(
      addressedTargetID: failure.addressedTargetID,
      participantID: failure.participantID,
      workspacePersonaID: failure.workspacePersonaID,
      personaTemplateID: failure.personaTemplateID,
      directiveID: failure.directiveID,
      triggerSource: failure.triggerSource.rawValue,
      systemEventMessageID: systemEventMessageID,
      requiredSkillIDs: failure.requiredSkillIDs,
      authorizedSkillIDs: failure.authorizedSkillIDs,
      failureReason: failure.failureReason.rawValue,
      systemEventBody: failure.systemEventBody
    )
  }

  private func scaffoldedContract(
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
}
