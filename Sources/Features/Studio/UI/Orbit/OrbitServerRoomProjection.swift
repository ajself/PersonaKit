import Foundation
import OrbitServerRuntime

enum OrbitServerRoomProjection {
  static func workspace(
    from snapshot: OrbitPhase1RealtimeSnapshot
  ) -> OrbitWorkspace {
    let room = snapshot.room
    let participants = projectedParticipants(from: room)
    let resolvedActivationPayloadsByID = resolvedActivationPayloads(from: room)
    let activationContractSnapshots = projectedActivationContractSnapshots(
      from: room,
      activationPayloadsByID: resolvedActivationPayloadsByID
    )
    let activationFailureRecords = projectedActivationFailureRecords(from: room)
    let activationRecords = projectedActivationRecords(
      from: room,
      participants: participants,
      activationPayloadsByID: resolvedActivationPayloadsByID
    )
    let interactionMode = projectedInteractionMode(from: room)
    let messages = projectedMessages(
      from: room,
      participants: participants
    )
    let threadID = room.thread.id.uuidString

    return OrbitWorkspace(
      schemaVersion: OrbitWorkspace.currentSchemaVersion,
      id: room.workspace.slug,
      displayName: room.workspace.name,
      purpose: room.channel.purpose,
      participants: participants,
      teams: projectedTeams(from: room),
      squads: projectedSquads(from: room),
      workspacePersonaMemberships: projectedWorkspacePersonaMemberships(from: room),
      activeThreadID: threadID,
      threads: [
        OrbitConversationThread(
          id: threadID,
          title: room.post.title ?? room.channel.name,
          interactionMode: interactionMode,
          createdSequence: 1,
          updatedSequence: max(messages.count, 1),
          messages: messages
        )
      ],
      activationRecords: activationRecords,
      activationContractSnapshots: activationContractSnapshots,
      activationFailureRecords: activationFailureRecords,
      nextMessageSequence: messages.count + 1,
      nextActivationSequence: activationRecords.count + 1,
      nextActivationFailureSequence: activationFailureRecords.count + 1
    )
  }

  private static func projectedParticipants(
    from room: OrbitPhase1RoomSnapshot
  ) -> [OrbitParticipant] {
    var participants = [
      OrbitParticipant(
        id: OrbitParticipantID.aj.rawValue,
        workspacePersonaID: nil,
        displayName: "AJ",
        roleLabel: "Founder",
        participantType: .human,
        personaTemplateID: nil,
        defaultDirectiveID: nil,
        requiredSkillIDs: [],
        authorizedSkillIDs: [],
        availability: .active,
        sortOrder: 1
      )
    ]

    let projectedWorkspacePersonas = room.workspacePersonas.sorted { lhs, rhs in
      if lhs.createdAt == rhs.createdAt {
        return lhs.displayName < rhs.displayName
      }
      return lhs.createdAt < rhs.createdAt
    }

    participants.append(
      contentsOf: projectedWorkspacePersonas.enumerated().map { index, workspacePersona in
        let participantID = projectedParticipantID(for: workspacePersona)
        let defaultParticipant = OrbitWorkspace.defaultWorkspace.participant(id: participantID)

        return OrbitParticipant(
          id: participantID,
          workspacePersonaID: workspacePersona.id.uuidString,
          displayName: workspacePersona.displayName,
          roleLabel: defaultParticipant?.roleLabel ?? projectedRoleLabel(for: workspacePersona.personaTemplateID),
          participantType: .ai,
          personaTemplateID: workspacePersona.personaTemplateID,
          defaultDirectiveID: workspacePersona.defaultDirectiveOverrideID ?? defaultParticipant?.defaultDirectiveID,
          requiredSkillIDs: defaultParticipant?.requiredSkillIDs ?? [],
          authorizedSkillIDs: defaultParticipant?.authorizedSkillIDs ?? [],
          availability: workspacePersona.status == .active ? .available : .idle,
          sortOrder: index + 2
        )
      }
    )

    return participants
  }

  private static func projectedTeams(
    from room: OrbitPhase1RoomSnapshot
  ) -> [OrbitTeam] {
    room.teams
      .sorted { lhs, rhs in
        if lhs.createdAt == rhs.createdAt {
          return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.createdAt < rhs.createdAt
      }
      .map { team in
        OrbitTeam(
          id: team.id.uuidString,
          workspaceID: team.workspaceID.uuidString,
          slug: team.slug,
          name: team.name,
          purpose: team.purpose,
          createdAt: team.createdAt
        )
      }
  }

  private static func projectedSquads(
    from room: OrbitPhase1RoomSnapshot
  ) -> [OrbitSquad] {
    room.squads
      .sorted { lhs, rhs in
        if lhs.createdAt == rhs.createdAt {
          return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.createdAt < rhs.createdAt
      }
      .map { squad in
        OrbitSquad(
          id: squad.id.uuidString,
          workspaceID: squad.workspaceID.uuidString,
          teamID: squad.teamID?.uuidString,
          slug: squad.slug,
          name: squad.name,
          purpose: squad.purpose,
          createdAt: squad.createdAt
        )
      }
  }

  private static func projectedWorkspacePersonaMemberships(
    from room: OrbitPhase1RoomSnapshot
  ) -> [OrbitWorkspacePersonaMembership] {
    room.workspacePersonaMemberships
      .sorted { lhs, rhs in
        if lhs.createdAt == rhs.createdAt {
          return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.createdAt < rhs.createdAt
      }
      .map { membership in
        OrbitWorkspacePersonaMembership(
          id: membership.id.uuidString,
          workspacePersonaID: membership.workspacePersonaID.uuidString,
          teamID: membership.teamID?.uuidString,
          squadID: membership.squadID?.uuidString,
          roleInGroup: membership.roleInGroup,
          createdAt: membership.createdAt
        )
      }
  }

  private static func projectedInteractionMode(
    from room: OrbitPhase1RoomSnapshot
  ) -> OrbitInteractionMode {
    if let latestActivation = room.personaActivations.sorted(by: activationSort).last {
      return projectedInteractionMode(for: latestActivation.responseMode)
    }

    let participantCount = room.postParticipants.filter {
      $0.participantType == .workspacePersona
    }.count

    return participantCount > 1 ? .lightweightMeeting : .directMessage
  }

  private static func projectedMessages(
    from room: OrbitPhase1RoomSnapshot,
    participants: [OrbitParticipant]
  ) -> [OrbitMessage] {
    let participantsByWorkspacePersonaID = Dictionary(
      uniqueKeysWithValues: participants.compactMap { participant -> (UUID, OrbitParticipant)? in
        guard
          let workspacePersonaID = participant.workspacePersonaID,
          let uuid = UUID(uuidString: workspacePersonaID)
        else {
          return nil
        }

        return (uuid, participant)
      }
    )

    return room.messages
      .sorted(by: messageSort)
      .enumerated()
      .map { index, message in
        OrbitMessage(
          id: message.id.uuidString,
          speakerParticipantID: projectedSpeakerParticipantID(
            for: message,
            participantsByWorkspacePersonaID: participantsByWorkspacePersonaID
          ),
          addressedParticipantID: projectedAddressedParticipantID(
            for: message,
            room: room,
            participantsByWorkspacePersonaID: participantsByWorkspacePersonaID
          ),
          body: message.body,
          order: index + 1,
          kind: projectedMessageKind(for: message.authorType)
        )
      }
  }

  private static func projectedActivationRecords(
    from room: OrbitPhase1RoomSnapshot,
    participants: [OrbitParticipant],
    activationPayloadsByID: [UUID: OrbitPhase1ActivationEventPayload]
  ) -> [OrbitActivationRecord] {
    let participantsByWorkspacePersonaID = Dictionary(
      uniqueKeysWithValues: participants.compactMap { participant -> (UUID, OrbitParticipant)? in
        guard
          let workspacePersonaID = participant.workspacePersonaID,
          let uuid = UUID(uuidString: workspacePersonaID)
        else {
          return nil
        }

        return (uuid, participant)
      }
    )
    let workspacePersonasByID = Dictionary(
      uniqueKeysWithValues: room.workspacePersonas.map { ($0.id, $0) }
    )

    return room.personaActivations
      .sorted(by: activationSort)
      .compactMap { activation -> OrbitActivationRecord? in
        guard
          let responseMessageID = responseMessageID(
            for: activation,
            in: room,
            workspacePersonasByID: workspacePersonasByID
          )
        else {
          return nil
        }

        let participant = participantsByWorkspacePersonaID[activation.resolvedWorkspacePersonaInstanceID]
        let workspacePersona = workspacePersonasByID[activation.resolvedWorkspacePersonaInstanceID]
        let contract = activationPayloadsByID[activation.id]?.contract

        return OrbitActivationRecord(
          id: activation.id.uuidString,
          workspaceID: room.workspace.slug,
          responseMessageID: responseMessageID,
          participantID: participant?.id ?? activation.resolvedWorkspacePersonaInstanceID.uuidString,
          workspacePersonaID: activation.resolvedWorkspacePersonaInstanceID.uuidString,
          personaTemplateID: workspacePersona?.personaTemplateID,
          directiveID: contract?.directiveID ?? workspacePersona?.defaultDirectiveOverrideID,
          responseMode: projectedInteractionMode(for: activation.responseMode),
          triggerSource: projectedTriggerSource(for: activation.responseMode),
          triggerMessageID: activation.triggerMessageID.uuidString,
          memoryInfluenced: false,
          memorySourceRefs: []
        )
      }
  }

  private static func projectedActivationContractSnapshots(
    from room: OrbitPhase1RoomSnapshot,
    activationPayloadsByID: [UUID: OrbitPhase1ActivationEventPayload]
  ) -> [OrbitActivationContractSnapshot] {
    room.personaActivations
      .sorted(by: activationSort)
      .compactMap { activation -> OrbitActivationContractSnapshot? in
        guard let contract = activationPayloadsByID[activation.id]?.contract else {
          return nil
        }

        return OrbitActivationContractSnapshot(
          id: OrbitWorkspace.activationContractSnapshotID(for: activation.id.uuidString),
          activationID: activation.id.uuidString,
          directiveSource: directiveSource(from: contract.directiveSource),
          kitIDs: contract.kitIDs,
          authorizedSkillIDs: contract.authorizedSkillIDs,
          stopPointIDs: contract.stopPointIDs,
          reviewGateIDs: contract.reviewGateIDs,
          memoryScopeIDs: contract.memoryScopeIDs
        )
      }
  }

  private static func projectedActivationFailureRecords(
    from room: OrbitPhase1RoomSnapshot
  ) -> [OrbitActivationFailureRecord] {
    room.postEvents
      .sorted(by: postEventSort)
      .compactMap { postEvent -> OrbitActivationFailureRecord? in
        guard postEvent.eventType == OrbitPhase1RealtimeEventCategory.activationFailed.rawValue else {
          return nil
        }

        guard
          let payload = try? OrbitPhase1RealtimeEventPayloadCodec.decode(
            OrbitPhase1ActivationEventPayload.self,
            from: postEvent.payloadJSON
          ),
          let failure = payload.failure,
          let triggerMessageID = payload.triggerMessageID,
          let triggerSource = OrbitActivationTriggerSource(rawValue: failure.triggerSource),
          let failureReason = OrbitActivationFailureReason(rawValue: failure.failureReason)
        else {
          return nil
        }

        return OrbitActivationFailureRecord(
          id: postEvent.id.uuidString,
          workspaceID: room.workspace.slug,
          addressedTargetID: failure.addressedTargetID,
          participantID: failure.participantID,
          workspacePersonaID: failure.workspacePersonaID,
          personaTemplateID: failure.personaTemplateID,
          directiveID: failure.directiveID,
          triggerSource: triggerSource,
          triggerMessageID: triggerMessageID.uuidString,
          systemEventMessageID: failure.systemEventMessageID.uuidString,
          requiredSkillIDs: failure.requiredSkillIDs,
          authorizedSkillIDs: failure.authorizedSkillIDs,
          failureReason: failureReason,
          systemEventBody: failure.systemEventBody
        )
      }
  }

  private static func projectedParticipantID(
    for workspacePersona: OrbitWorkspacePersonaRecord
  ) -> String {
    switch workspacePersona.displayName.lowercased() {
    case "samwise":
      return OrbitParticipantID.samwise.rawValue
    case "proddoc":
      return OrbitParticipantID.prodDoc.rawValue
    default:
      return workspacePersona.id.uuidString
    }
  }

  private static func projectedRoleLabel(
    for personaTemplateID: String
  ) -> String {
    switch personaTemplateID {
    case "samwise":
      return "Trusted Partner"
    case "venture-product-steward":
      return "Product"
    default:
      return "Collaborator"
    }
  }

  private static func projectedSpeakerParticipantID(
    for message: OrbitMessageRecord,
    participantsByWorkspacePersonaID: [UUID: OrbitParticipant]
  ) -> String {
    switch message.authorType {
    case .user:
      return OrbitParticipantID.aj.rawValue
    case .workspacePersona:
      if let workspacePersonaID = UUID(uuidString: message.authorID) {
        return participantsByWorkspacePersonaID[workspacePersonaID]?.id
          ?? projectedParticipantIDFromAuthorID(message.authorID)
      }

      return projectedParticipantIDFromAuthorID(message.authorID)
    case .system:
      return OrbitParticipantID.samwise.rawValue
    }
  }

  private static func projectedParticipantIDFromAuthorID(
    _ authorID: String
  ) -> String {
    if authorID.localizedCaseInsensitiveContains("samwise") {
      return OrbitParticipantID.samwise.rawValue
    }

    if authorID.localizedCaseInsensitiveContains("proddoc")
      || authorID.localizedCaseInsensitiveContains("venture-product-steward")
    {
      return OrbitParticipantID.prodDoc.rawValue
    }

    return authorID
  }

  private static func projectedMessageKind(
    for authorType: OrbitParticipantAuthorType
  ) -> OrbitMessageKind {
    switch authorType {
    case .user:
      return .user
    case .workspacePersona:
      return .participantResponse
    case .system:
      return .systemEvent
    }
  }

  private static func projectedAddressedParticipantID(
    for message: OrbitMessageRecord,
    room: OrbitPhase1RoomSnapshot,
    participantsByWorkspacePersonaID: [UUID: OrbitParticipant]
  ) -> String? {
    switch message.authorType {
    case .user:
      let matchingActivations = room.personaActivations
        .filter { $0.triggerMessageID == message.id }
        .sorted(by: activationSort)

      guard let firstActivation = matchingActivations.first else {
        return nil
      }

      switch firstActivation.responseMode {
      case .currentThread:
        return nil
      case .directAddress:
        if firstActivation.addressedTargetKind == .collaborator {
          if let uuid = UUID(uuidString: firstActivation.addressedTargetReferenceID) {
            return participantsByWorkspacePersonaID[uuid]?.id
              ?? firstActivation.addressedTargetReferenceID
          }

          return firstActivation.addressedTargetReferenceID
        }

        return firstActivation.addressedTargetReferenceID
      case .lightweightMeeting:
        return firstActivation.addressedTargetReferenceID
      }
    case .workspacePersona:
      return OrbitParticipantID.aj.rawValue
    case .system:
      return nil
    }
  }

  private static func responseMessageID(
    for activation: OrbitPersonaActivationRecord,
    in room: OrbitPhase1RoomSnapshot,
    workspacePersonasByID: [UUID: OrbitWorkspacePersonaRecord]
  ) -> String? {
    let workspacePersona = workspacePersonasByID[activation.resolvedWorkspacePersonaInstanceID]

    return room.messages
      .filter { message in
        message.authorType == .workspacePersona
          && message.replyToMessageID == activation.triggerMessageID
          && messageMatchesResolvedWorkspacePersona(
            message,
            activation: activation,
            workspacePersona: workspacePersona
          )
      }
      .sorted(by: messageSort)
      .first?
      .id
      .uuidString
  }

  private static func messageMatchesResolvedWorkspacePersona(
    _ message: OrbitMessageRecord,
    activation: OrbitPersonaActivationRecord,
    workspacePersona: OrbitWorkspacePersonaRecord?
  ) -> Bool {
    if message.authorID == activation.resolvedWorkspacePersonaInstanceID.uuidString {
      return true
    }

    guard let workspacePersona else {
      return false
    }

    let authorID = message.authorID.lowercased()

    return authorID.contains(workspacePersona.displayName.lowercased())
      || authorID.contains(workspacePersona.personaTemplateID.lowercased())
  }

  private static func projectedInteractionMode(
    for responseMode: OrbitCanonicalResponseMode
  ) -> OrbitInteractionMode {
    responseMode == .lightweightMeeting ? .lightweightMeeting : .directMessage
  }

  private static func projectedTriggerSource(
    for responseMode: OrbitCanonicalResponseMode
  ) -> OrbitActivationTriggerSource {
    switch responseMode {
    case .currentThread:
      return .generalThreadReply
    case .directAddress:
      return .directAddress
    case .lightweightMeeting:
      return .meetingInvocation
    }
  }

  private static func resolvedActivationPayloads(
    from room: OrbitPhase1RoomSnapshot
  ) -> [UUID: OrbitPhase1ActivationEventPayload] {
    room.postEvents
      .sorted(by: postEventSort)
      .reduce(into: [UUID: OrbitPhase1ActivationEventPayload]()) { payloadsByID, postEvent in
        guard postEvent.eventType == OrbitPhase1RealtimeEventCategory.activationResolved.rawValue else {
          return
        }

        guard
          let payload = try? OrbitPhase1RealtimeEventPayloadCodec.decode(
            OrbitPhase1ActivationEventPayload.self,
            from: postEvent.payloadJSON
          ),
          let activationID = payload.activationID
        else {
          return
        }

        payloadsByID[activationID] = payload
      }
  }

  private static func directiveSource(
    from rawValue: String?
  ) -> OrbitDirectiveSource {
    rawValue
      .flatMap(OrbitDirectiveSource.init(rawValue:))
      ?? .participantDefault
  }

  private static func messageSort(
    _ lhs: OrbitMessageRecord,
    _ rhs: OrbitMessageRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }

  private static func activationSort(
    _ lhs: OrbitPersonaActivationRecord,
    _ rhs: OrbitPersonaActivationRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }

  private static func postEventSort(
    _ lhs: OrbitPostEventRecord,
    _ rhs: OrbitPostEventRecord
  ) -> Bool {
    if lhs.createdAt == rhs.createdAt {
      return lhs.id.uuidString < rhs.id.uuidString
    }

    return lhs.createdAt < rhs.createdAt
  }
}
