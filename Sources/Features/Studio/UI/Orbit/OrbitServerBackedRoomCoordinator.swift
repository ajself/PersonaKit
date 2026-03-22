import Foundation
import OrbitServerRuntime

enum OrbitServerBackedRoomCoordinatorError: LocalizedError, Equatable {
  case projectedWorkspaceUnavailable
  case collaboratorWorkspacePersonaMissing(String)
  case preflightUserMessageUnavailable
  case preflightActivationRecordUnavailable(String)
  case preflightContractSnapshotUnavailable(String)
  case preflightActivationFailureUnavailable(String)
  case promotionRequiresResolvedGroupTarget

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
    case .promotionRequiresResolvedGroupTarget:
      return "Orbit can only promote a resolved team or squad target into a dedicated meeting room."
    }
  }
}

private struct OrbitServerBackedRoomPromotionAttempt {
  let targetResolution: OrbitTargetResolution
  let meetingRequest: OrbitPhase1CreateMeetingRoomRequest
}

struct OrbitServerBackedRoomPromotionRequest: Equatable, Sendable {
  let title: String?

  init(
    title: String? = nil
  ) {
    self.title = title
  }
}

private struct OrbitServerBackedPreflightConversationTurn {
  let workspace: OrbitWorkspace
  let targetResolution: OrbitTargetResolution?
  let resolvedContractsByParticipantID: [String: OrbitResolvedActivationContract]
  let createdMessages: [OrbitMessage]
  let userMessage: OrbitMessage
}

struct OrbitServerBackedRoomCoordinator {
  private(set) var roomState = OrbitServerBackedRoomState()

  mutating func apply(
    _ response: OrbitPhase1RealtimeTransportResponse
  ) throws {
    try roomState.apply(response)
  }

  mutating func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor? = nil,
    transport: some OrbitPhase1RealtimeTransportServing
  ) async throws {
    let response = try await transport.connect(
      request: OrbitPhase1RealtimeConnectRequest(
        scope: scope,
        cursor: cursor
      )
    )

    try roomState.apply(response)
  }

  mutating func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    cursor: OrbitPhase1ReplayCursor? = nil,
    client: OrbitServerBackedRoomClient
  ) async throws {
    let response = try await client.connect(
      scope: scope,
      cursor: cursor
    )
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
        postID: scope.postID,
        authorID: authorID,
        body: body
      )
    )

    try await reconnect(scope: scope, client: client)
  }

  @MainActor
  mutating func appendConversationTurn(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    authorID: String,
    body: String,
    addressedParticipantID: String?,
    promotion: OrbitServerBackedRoomPromotionRequest? = nil,
    resolveContract: ((OrbitParticipant) throws -> OrbitResolvedActivationContract)? = nil,
    client: OrbitServerBackedRoomClient
  ) async throws {
    if let promotion {
      let promotionAttempt = try promotionAttempt(
        scope: scope,
        authorID: authorID,
        addressedParticipantID: addressedParticipantID,
        promotion: promotion
      )

      do {
        let promotedMeeting = try await client.promoteMeetingRoom(
          OrbitPhase1PromoteMeetingRoomRequest(
            originPostID: scope.postID,
            meeting: promotionAttempt.meetingRequest,
            promotion: promotionPayload(
              for: promotionAttempt,
              initiatedByParticipantID: authorID
            )
          )
        )

        let promotedScope = try await promoteConversationTurn(
          result: promotedMeeting.meeting,
          client: client
        )

        try await appendConversationTurn(
          scope: promotedScope,
          authorID: authorID,
          body: body,
          addressedParticipantID: addressedParticipantID,
          resolveContract: resolveContract,
          client: client
        )

        return
      } catch {
        _ = try await client.appendMeetingPromotionEvent(
          OrbitPhase1AppendMeetingPromotionEventRequest(
            workspaceSlug: scope.workspaceSlug,
            channelSlug: scope.channelSlug,
            postID: scope.postID,
            promotion: promotionPayload(
              for: promotionAttempt,
              initiatedByParticipantID: authorID,
              failure: OrbitPhase1MeetingPromotionFailurePayload(
                systemEventMessageID: UUID(),
                systemEventBody: promotionFailureBody(
                  for: promotionAttempt.targetResolution,
                  error: error
                ),
                detail: promotionFailureDetail(error)
              )
            )
          )
        )
      }

      try await appendConversationTurn(
        scope: scope,
        authorID: authorID,
        body: body,
        addressedParticipantID: addressedParticipantID,
        resolveContract: resolveContract,
        client: client
      )

      return
    }

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
        postID: scope.postID,
        authorID: authorID,
        body: body
      )
    )

    do {
      for message in preflight.createdMessages where message.id != preflight.userMessage.id {
        switch message.kind {
        case .user:
          continue
        case .systemEvent:
          if let activationFailure = preflight.workspace.activationFailureRecordForSystemEvent(message.id) {
            let systemEventMessageID = UUID()

            _ = try await client.appendActivationFailure(
              OrbitPhase1AppendActivationFailureRequest(
                workspaceSlug: scope.workspaceSlug,
                channelSlug: scope.channelSlug,
                postID: scope.postID,
                initiatedByParticipantID: authorID,
                triggerMessageID: appendResult.message.id,
                failure: failurePayload(
                  from: activationFailure,
                  systemEventMessageID: systemEventMessageID
                )
              )
            )
          } else {
            _ = try await client.appendSystemMessage(
              OrbitPhase1AppendSystemMessageRequest(
                workspaceSlug: scope.workspaceSlug,
                channelSlug: scope.channelSlug,
                postID: scope.postID,
                body: message.body,
                replyToMessageID: appendResult.message.id
              )
            )
          }
        case .participantResponse:
          let activation = try activationRecord(
            for: message,
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
              postID: scope.postID,
              workspacePersonaID: workspacePersonaID,
              initiatedByParticipantID: authorID,
              triggerMessageID: appendResult.message.id,
              addressedTargetKind: addressedTargetKind(
                for: preflight.targetResolution
              ),
              addressedTargetReferenceID: addressedTargetReferenceID(
                for: participant,
                targetResolution: preflight.targetResolution
              ),
              responseMode: responseMode(
                for: preflight.targetResolution
              ),
              body: message.body,
              contract: contractPayload(
                activation: activation,
                contractSnapshot: contractSnapshot,
                resolvedContract: preflight.resolvedContractsByParticipantID[activation.participantID]
              )
            )
          )
        }
      }

      try await reconnect(scope: scope, client: client)
    } catch {
      try? await reconnect(scope: scope, client: client)
      throw error
    }
  }

  @MainActor
  private mutating func promoteConversationTurn(
    result: OrbitPhase1CreateMeetingRoomResult,
    client: OrbitServerBackedRoomClient
  ) async throws -> OrbitPhase1RealtimeSubscriptionScope {
    try await connect(scope: result.scope, client: client)

    return result.scope
  }

  mutating func reconnect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    client: OrbitServerBackedRoomClient
  ) async throws {
    try await connect(
      scope: scope,
      cursor: roomState.session?.replayCursor,
      client: client
    )
  }

  private func responseMode(
    for targetResolution: OrbitTargetResolution?
  ) -> OrbitCanonicalResponseMode {
    guard let targetResolution else {
      return .currentThread
    }

    return targetResolution.targetKind == .collaborator
      ? .directAddress
      : .currentThread
  }

  private func addressedTargetKind(
    for targetResolution: OrbitTargetResolution?
  ) -> OrbitAddressedTargetKind {
    targetResolution?.targetKind ?? .collaborator
  }

  private func addressedTargetReferenceID(
    for participant: OrbitParticipant,
    targetResolution: OrbitTargetResolution?
  ) -> String {
    targetResolution?.targetReferenceID ?? participant.workspacePersonaID ?? participant.id
  }

  private func preflightConversationTurn(
    in projectedWorkspace: OrbitWorkspace,
    body: String,
    addressedParticipantID: String?,
    resolveContract: ((OrbitParticipant) throws -> OrbitResolvedActivationContract)? = nil
  ) throws -> OrbitServerBackedPreflightConversationTurn {
    var stagedWorkspace = projectedWorkspace
    var resolvedContractsByParticipantID = [String: OrbitResolvedActivationContract]()
    let targetResolution = addressedParticipantID.flatMap { addressedParticipantID in
      OrbitParticipantResponseBridge.targetResolution(
        in: projectedWorkspace,
        addressedParticipantID: addressedParticipantID
      )
    }

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
      targetResolution: targetResolution,
      resolvedContractsByParticipantID: resolvedContractsByParticipantID,
      createdMessages: createdMessages,
      userMessage: userMessage
    )
  }

  private func promotionAttempt(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    authorID: String,
    addressedParticipantID: String?,
    promotion: OrbitServerBackedRoomPromotionRequest
  ) throws -> OrbitServerBackedRoomPromotionAttempt {
    guard let workspace = roomState.projectedWorkspace else {
      throw OrbitServerBackedRoomCoordinatorError.projectedWorkspaceUnavailable
    }

    let targetResolution = try promotedTargetResolution(
      addressedParticipantID: addressedParticipantID,
      in: workspace
    )

    return OrbitServerBackedRoomPromotionAttempt(
      targetResolution: targetResolution,
      meetingRequest: try meetingRoomRequest(
        scope: scope,
        authorID: authorID,
        promotion: promotion,
        targetResolution: targetResolution,
        in: workspace
      )
    )
  }

  private func promotedTargetResolution(
    addressedParticipantID: String?,
    in workspace: OrbitWorkspace
  ) throws -> OrbitTargetResolution {
    guard let addressedParticipantID else {
      throw OrbitServerBackedRoomCoordinatorError.promotionRequiresResolvedGroupTarget
    }

    let targetResolution = OrbitParticipantResponseBridge.targetResolution(
      in: workspace,
      addressedParticipantID: addressedParticipantID
    )

    guard
      targetResolution.status == .resolved,
      targetResolution.targetKind != .collaborator
    else {
      throw OrbitServerBackedRoomCoordinatorError.promotionRequiresResolvedGroupTarget
    }

    return targetResolution
  }

  private func meetingRoomRequest(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    authorID: String,
    promotion: OrbitServerBackedRoomPromotionRequest,
    targetResolution: OrbitTargetResolution,
    in workspace: OrbitWorkspace
  ) throws -> OrbitPhase1CreateMeetingRoomRequest {
    let includedReasonsByParticipantID: [String: OrbitTargetParticipantReason] = Dictionary(
      uniqueKeysWithValues: targetResolution.includedParticipantReasons.compactMap { reason in
        guard let participantID = reason.participantID else {
          return nil
        }

        return (participantID, reason)
      }
    )
    let members = try targetResolution.includedParticipants.map { participant in
      guard
        let workspacePersonaIDString = participant.workspacePersonaID,
        let workspacePersonaID = UUID(uuidString: workspacePersonaIDString)
      else {
        throw OrbitServerBackedRoomCoordinatorError.collaboratorWorkspacePersonaMissing(
          participant.id
        )
      }

      return OrbitPhase1MeetingMemberSpec(
        workspacePersonaID: workspacePersonaID,
        participationRole: .contributor,
        selectedReason:
          includedReasonsByParticipantID[participant.id]?.explanation
          ?? "Orbit selected \(participant.displayName) for the promoted \(targetResolution.targetKind.rawValue) meeting."
      )
    }

    return OrbitPhase1CreateMeetingRoomRequest(
      workspaceSlug: scope.workspaceSlug,
      channelSlug: scope.channelSlug,
      title: meetingTitle(
        for: targetResolution,
        promotion: promotion
      ),
      meetingType: meetingType(for: targetResolution.targetKind),
      startedByParticipantType: .user,
      startedByParticipantID: authorID,
      members: members
    )
  }

  private func meetingTitle(
    for targetResolution: OrbitTargetResolution,
    promotion: OrbitServerBackedRoomPromotionRequest
  ) -> String {
    guard
      let title = promotion.title?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty
    else {
      return "\(targetResolution.targetDisplayName) Meeting"
    }

    return title
  }

  private func meetingType(
    for targetKind: OrbitAddressedTargetKind
  ) -> OrbitMeetingType {
    switch targetKind {
    case .team:
      return .team
    case .squad:
      return .squad
    case .collaborator:
      return .adHoc
    }
  }

  private func promotionPayload(
    for attempt: OrbitServerBackedRoomPromotionAttempt,
    initiatedByParticipantID: String,
    failure: OrbitPhase1MeetingPromotionFailurePayload? = nil
  ) -> OrbitPhase1MeetingPromotionEventPayload {
    OrbitPhase1MeetingPromotionEventPayload(
      initiatedByParticipantID: initiatedByParticipantID,
      addressedTargetKind: attempt.targetResolution.targetKind.rawValue,
      addressedTargetReferenceID: attempt.targetResolution.targetReferenceID,
      targetDisplayName: attempt.targetResolution.targetDisplayName,
      meetingType: attempt.meetingRequest.meetingType.rawValue,
      title: attempt.meetingRequest.title,
      memberWorkspacePersonaIDs: attempt.meetingRequest.members
        .map(\.workspacePersonaID)
        .sorted { $0.uuidString < $1.uuidString },
      failure: failure
    )
  }

  private func promotionFailureBody(
    for targetResolution: OrbitTargetResolution,
    error: Error
  ) -> String {
    """
    Orbit meeting promotion failed
    attempted target: kind=\(targetResolution.targetKind.rawValue) reference=\(targetResolution.targetReferenceID) workspace=\(targetResolution.workspaceID)
    outcome: promotion did not complete
    fallback: current thread
    detail: \(promotionFailureDetail(error))
    """
  }

  private func promotionFailureDetail(
    _ error: Error
  ) -> String {
    error.localizedDescription
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
