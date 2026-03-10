import Foundation

enum OrbitParticipantResponseBridge {
  static func addressedParticipants(
    in workspace: OrbitWorkspace,
    addressedParticipantID: String?
  ) -> [OrbitParticipant] {
    let aiParticipants = workspace.participants
      .filter { $0.participantType == .ai }
      .sorted { $0.sortOrder < $1.sortOrder }

    guard let addressedParticipantID else {
      return aiParticipants.first.map { [$0] } ?? []
    }

    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return aiParticipants
    }

    guard
      let participant = workspace.participant(id: addressedParticipantID),
      participant.participantType == .ai
    else {
      return []
    }

    return [participant]
  }

  static func interactionMode(
    for addressedParticipantID: String?
  ) -> OrbitInteractionMode {
    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return .lightweightMeeting
    }

    return .directMessage
  }

  static func triggerSource(
    for addressedParticipantID: String?
  ) -> OrbitActivationTriggerSource {
    if addressedParticipantID == OrbitAddressTargetID.foundingGroup.rawValue {
      return .meetingInvocation
    }

    if addressedParticipantID == nil {
      return .generalThreadReply
    }

    return .directAddress
  }

  static func systemEventBody(
    for participants: [OrbitParticipant],
    triggerSource: OrbitActivationTriggerSource
  ) -> String? {
    guard triggerSource == .meetingInvocation else {
      return nil
    }

    let participantNames = participants.map(\.displayName).joined(separator: " and ")
    return "AJ invited \(participantNames) into the active lightweight meeting."
  }

  static func responseBody(
    for participant: OrbitParticipant,
    triggerMessage: OrbitMessage,
    triggerSource: OrbitActivationTriggerSource
  ) -> String {
    let focus = focusSnippet(from: triggerMessage.body)

    switch participant.id {
    case OrbitParticipantID.samwise.rawValue:
      return samwiseResponse(
        focus: focus,
        triggerSource: triggerSource
      )
    case OrbitParticipantID.prodDoc.rawValue:
      return prodDocResponse(
        focus: focus,
        triggerSource: triggerSource
      )
    default:
      return "I am tracking \"\(focus)\" inside the active Orbit thread."
    }
  }

  private static func samwiseResponse(
    focus: String,
    triggerSource: OrbitActivationTriggerSource
  ) -> String {
    switch triggerSource {
    case .directAddress:
      return
        "I am on it. I am treating \"\(focus)\" as the active objective and keeping the first checkpoint bounded to workspace, roster, conversation, and trace."
    case .meetingInvocation:
      return
        "I am in the room. I will turn \"\(focus)\" into the next concrete execution step and keep the Orbit lane moving without widening scope."
    case .generalThreadReply:
      return "I am tracking \"\(focus)\" as the active thread objective and I will keep the next move concrete."
    }
  }

  private static func prodDocResponse(
    focus: String,
    triggerSource: OrbitActivationTriggerSource
  ) -> String {
    switch triggerSource {
    case .directAddress:
      return
        "Product read: \"\(focus)\" belongs in the first Orbit command-center loop if it makes collaboration clearer without drifting into memory or summary scope."
    case .meetingInvocation:
      return
        "Product lens: \"\(focus)\" should make the command-center surface feel more intentional than chat while staying light enough for the first checkpoint."
    case .generalThreadReply:
      return
        "Product note: \"\(focus)\" should improve clarity of the active Orbit workspace before we broaden the surface area."
    }
  }

  private static func focusSnippet(
    from body: String
  ) -> String {
    let normalized =
      body
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .split(separator: " ", omittingEmptySubsequences: true)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard normalized.count > 96 else {
      return normalized
    }

    let cutoffIndex = normalized.index(normalized.startIndex, offsetBy: 96)
    return normalized[..<cutoffIndex].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
  }
}
