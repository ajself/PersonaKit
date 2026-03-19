import Foundation
import OrbitServerRuntime

enum OrbitServerRoomProjection {
  static func workspace(
    from snapshot: OrbitPhase1RealtimeSnapshot
  ) -> OrbitWorkspace {
    let room = snapshot.room
    let participants = projectedParticipants(from: room)
    let interactionMode = projectedInteractionMode(from: room)
    let messages = projectedMessages(from: room)
    let threadID = room.thread.id.uuidString

    return OrbitWorkspace(
      schemaVersion: OrbitWorkspace.currentSchemaVersion,
      id: room.workspace.slug,
      displayName: room.workspace.name,
      purpose: room.channel.purpose,
      participants: participants,
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
      activationRecords: [],
      activationContractSnapshots: [],
      activationFailureRecords: [],
      nextMessageSequence: messages.count + 1,
      nextActivationSequence: 1,
      nextActivationFailureSequence: 1
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
        OrbitParticipant(
          id: projectedParticipantID(for: workspacePersona),
          workspacePersonaID: workspacePersona.id.uuidString,
          displayName: workspacePersona.displayName,
          roleLabel: projectedRoleLabel(for: workspacePersona.personaTemplateID),
          participantType: .ai,
          personaTemplateID: workspacePersona.personaTemplateID,
          defaultDirectiveID: workspacePersona.defaultDirectiveOverrideID,
          requiredSkillIDs: [],
          authorizedSkillIDs: [],
          availability: workspacePersona.status == .active ? .available : .idle,
          sortOrder: index + 2
        )
      }
    )

    return participants
  }

  private static func projectedInteractionMode(
    from room: OrbitPhase1RoomSnapshot
  ) -> OrbitInteractionMode {
    let participantCount = room.postParticipants.filter {
      $0.participantType == .workspacePersona
    }.count

    return participantCount > 1 ? .lightweightMeeting : .directMessage
  }

  private static func projectedMessages(
    from room: OrbitPhase1RoomSnapshot
  ) -> [OrbitMessage] {
    room.messages.enumerated().map { index, message in
      OrbitMessage(
        id: message.id.uuidString,
        speakerParticipantID: projectedSpeakerParticipantID(for: message.authorType, authorID: message.authorID),
        addressedParticipantID: nil,
        body: message.body,
        order: index + 1,
        kind: projectedMessageKind(for: message.authorType)
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
    for authorType: OrbitParticipantAuthorType,
    authorID: String
  ) -> String {
    switch authorType {
    case .user:
      return OrbitParticipantID.aj.rawValue
    case .workspacePersona:
      return projectedParticipantIDFromAuthorID(authorID)
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
}
