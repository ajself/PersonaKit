import Foundation

struct OrbitWorkspace: Codable, Equatable {
  static let currentSchemaVersion = 1

  var schemaVersion = OrbitWorkspace.currentSchemaVersion
  var id: String
  var displayName: String
  var purpose: String
  var participants: [OrbitParticipant]
  var activeThreadID: String
  var threads: [OrbitConversationThread]
  var activationRecords: [OrbitActivationRecord]
  var nextMessageSequence: Int
  var nextActivationSequence: Int

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

    threads[threadIndex].interactionMode =
      OrbitParticipantResponseBridge.interactionMode(for: addressedParticipantID)

    var createdMessages = [triggerMessage]

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

    activationRecords.append(
      OrbitActivationRecord(
        id: Self.activationID(for: nextActivationSequence),
        responseMessageID: responseMessage.id,
        participantID: participant.id,
        personaID: participant.personaID,
        directiveID: participant.defaultDirectiveID,
        triggerSource: triggerSource,
        triggerMessageID: triggerMessage.id,
        memoryInfluenced: false
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
  let displayName: String
  let roleLabel: String
  let participantType: OrbitParticipantType
  let personaID: String?
  let defaultDirectiveID: String?
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
  let responseMessageID: String
  let participantID: String
  let personaID: String?
  let directiveID: String?
  let triggerSource: OrbitActivationTriggerSource
  let triggerMessageID: String?
  let memoryInfluenced: Bool
}

enum OrbitActivationTriggerSource: String, Codable, Equatable {
  case directAddress
  case meetingInvocation
  case generalThreadReply
}
