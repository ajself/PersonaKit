import Foundation
import OrbitServerRuntime

enum OrbitParticipantResponseBridge {
  static func targetResolution(
    in workspace: OrbitWorkspace,
    addressedParticipantID: String
  ) -> OrbitTargetResolution {
    let matchingTeam = workspace.team(slug: addressedParticipantID)
    let matchingSquad = workspace.squad(slug: addressedParticipantID)

    if matchingTeam != nil && matchingSquad != nil {
      return OrbitTargetResolution(
        status: .blocked,
        targetKind: .team,
        targetReferenceID: addressedParticipantID,
        targetDisplayName: addressedParticipantID,
        workspaceID: workspace.id,
        includedParticipants: [],
        includedParticipantReasons: [],
        excludedParticipantReasons: [],
        outcomeReasonCategory: .missingOrAmbiguousTarget,
        outcomeExplanation:
          "Orbit could not resolve a single target for \(addressedParticipantID) in workspace \(workspace.id)."
      )
    }

    if let team = matchingTeam {
      return groupTargetResolution(
        in: workspace,
        targetKind: .team,
        targetReferenceID: team.slug,
        targetDisplayName: team.name,
        memberships: workspace.workspacePersonaMemberships.filter { $0.teamID == team.id },
        includedReasonCategory: .teamMembership
      )
    }

    if let squad = matchingSquad {
      return groupTargetResolution(
        in: workspace,
        targetKind: .squad,
        targetReferenceID: squad.slug,
        targetDisplayName: squad.name,
        memberships: workspace.workspacePersonaMemberships.filter { $0.squadID == squad.id },
        includedReasonCategory: .squadMembership
      )
    }

    guard
      let participant = workspace.participant(id: addressedParticipantID),
      participant.participantType == .ai
    else {
      return OrbitTargetResolution(
        status: .blocked,
        targetKind: .collaborator,
        targetReferenceID: addressedParticipantID,
        targetDisplayName: addressedParticipantID,
        workspaceID: workspace.id,
        includedParticipants: [],
        includedParticipantReasons: [],
        excludedParticipantReasons: [],
        outcomeReasonCategory: .missingOrAmbiguousTarget,
        outcomeExplanation:
          "Orbit could not resolve collaborator \(addressedParticipantID) in workspace \(workspace.id)."
      )
    }

    let targetReferenceID = participant.workspacePersonaID ?? participant.id

    return OrbitTargetResolution(
      status: .resolved,
      targetKind: .collaborator,
      targetReferenceID: targetReferenceID,
      targetDisplayName: participant.displayName,
      workspaceID: workspace.id,
      includedParticipants: [participant],
      includedParticipantReasons: [
        OrbitTargetParticipantReason(
          participantID: participant.id,
          workspacePersonaID: participant.workspacePersonaID,
          displayName: participant.displayName,
          reasonCategory: .directTarget,
          sourceTargetKind: .collaborator,
          sourceTargetReferenceID: targetReferenceID,
          explanation:
            "Orbit resolved the direct collaborator target to \(participant.displayName) in the active workspace."
        )
      ],
      excludedParticipantReasons: [],
      outcomeReasonCategory: nil,
      outcomeExplanation: nil
    )
  }

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

    return targetResolution(
      in: workspace,
      addressedParticipantID: addressedParticipantID
    ).includedParticipants
  }

  static func interactionMode(
    in workspace: OrbitWorkspace,
    addressedParticipantID: String?
  ) -> OrbitInteractionMode {
    guard let addressedParticipantID else {
      return .directMessage
    }

    let targetKind = targetResolution(
      in: workspace,
      addressedParticipantID: addressedParticipantID
    ).targetKind

    return targetKind == .collaborator ? .directMessage : .lightweightMeeting
  }

  static func triggerSource(
    in workspace: OrbitWorkspace,
    addressedParticipantID: String?
  ) -> OrbitActivationTriggerSource {
    guard let addressedParticipantID else {
      return .generalThreadReply
    }

    let targetKind = targetResolution(
      in: workspace,
      addressedParticipantID: addressedParticipantID
    ).targetKind

    return targetKind == .collaborator ? .directAddress : .meetingInvocation
  }

  static func systemEventBody(
    for targetResolution: OrbitTargetResolution?,
    in workspace: OrbitWorkspace? = nil
  ) -> String? {
    guard let targetResolution else {
      return nil
    }

    var summaryLines = [
      "Orbit target expansion",
      "resolved target: kind=\(targetResolution.targetKind.rawValue) reference=\(targetResolution.targetReferenceID) workspace=\(targetResolution.workspaceID) status=\(targetResolution.status.rawValue)",
    ]

    if let outcomeReasonCategory = targetResolution.outcomeReasonCategory {
      summaryLines.append(
        "outcome: reasonCategory=\(outcomeReasonCategory.rawValue) | \(targetResolution.outcomeExplanation ?? "-")"
      )
    }

    summaryLines.append(
      participantLines(
        title: "included participants",
        reasons: targetResolution.includedParticipantReasons
      )
    )

    if !targetResolution.excludedParticipantReasons.isEmpty {
      summaryLines.append(
        participantLines(
          title: "excluded participants",
          reasons: targetResolution.excludedParticipantReasons
        )
      )
    }

    if let workspace,
      let expectationLines = participantStateLines(
        in: workspace,
        targetResolution: targetResolution,
        stateByParticipantID: Dictionary(
          uniqueKeysWithValues: targetResolution.includedParticipants.map { ($0.id, .pending) }
        )
      )
    {
      summaryLines.append(expectationLines)
      summaryLines.append("exchange state: \(OrbitGroupExchangeState.active.rawValue)")
    }

    return summaryLines.joined(separator: "\n")
  }

  static func exchangeStateSystemEventBody(
    for targetResolution: OrbitTargetResolution?,
    in workspace: OrbitWorkspace,
    repliedParticipantIDs: Set<String>,
    failedParticipantIDs: Set<String>
  ) -> String? {
    guard
      let targetResolution,
      targetResolution.status == .resolved,
      targetResolution.targetKind != .collaborator
    else {
      return nil
    }

    let stateByParticipantID = Dictionary(
      uniqueKeysWithValues: targetResolution.includedParticipants.map { participant in
        let state: OrbitGroupParticipantState

        if failedParticipantIDs.contains(participant.id) {
          state = .failed
        } else if repliedParticipantIDs.contains(participant.id) {
          state = .replied
        } else {
          state = .pending
        }

        return (participant.id, state)
      }
    )
    let exchangeState = exchangeState(
      for: targetResolution,
      stateByParticipantID: stateByParticipantID
    )

    var summaryLines = [
      "Orbit exchange state",
      "resolved target: kind=\(targetResolution.targetKind.rawValue) reference=\(targetResolution.targetReferenceID) workspace=\(targetResolution.workspaceID) state=\(exchangeState.rawValue)",
    ]

    if let participantLines = participantStateLines(
      in: workspace,
      targetResolution: targetResolution,
      stateByParticipantID: stateByParticipantID
    ) {
      summaryLines.append(participantLines)
    }

    return summaryLines.joined(separator: "\n")
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

  private static func groupTargetResolution(
    in workspace: OrbitWorkspace,
    targetKind: OrbitAddressedTargetKind,
    targetReferenceID: String,
    targetDisplayName: String,
    memberships: [OrbitWorkspacePersonaMembership],
    includedReasonCategory: OrbitTargetReasonCategory
  ) -> OrbitTargetResolution {
    let orderedMemberships = orderedUniqueMemberships(from: memberships)

    guard !orderedMemberships.isEmpty else {
      return OrbitTargetResolution(
        status: .empty,
        targetKind: targetKind,
        targetReferenceID: targetReferenceID,
        targetDisplayName: targetDisplayName,
        workspaceID: workspace.id,
        includedParticipants: [],
        includedParticipantReasons: [],
        excludedParticipantReasons: [],
        outcomeReasonCategory: .emptyGroup,
        outcomeExplanation:
          "\(targetDisplayName) has no persisted workspace persona members in workspace \(workspace.id)."
      )
    }

    var includedParticipants = [OrbitParticipant]()
    var includedParticipantReasons = [OrbitTargetParticipantReason]()
    var excludedParticipantReasons = [OrbitTargetParticipantReason]()

    for membership in orderedMemberships {
      guard let participant = workspace.participant(workspacePersonaID: membership.workspacePersonaID) else {
        excludedParticipantReasons.append(
          excludedReason(
            displayName: membership.workspacePersonaID,
            workspacePersonaID: membership.workspacePersonaID,
            reasonCategory: .membershipUnresolved,
            targetKind: targetKind,
            targetReferenceID: targetReferenceID,
            explanation:
              "Orbit could not map persisted membership \(membership.id) to a visible workspace persona in the active workspace."
          )
        )
        continue
      }

      guard participant.participantType == .ai else {
        excludedParticipantReasons.append(
          excludedReason(
            displayName: participant.displayName,
            participantID: participant.id,
            workspacePersonaID: participant.workspacePersonaID,
            reasonCategory: .membershipUnresolved,
            targetKind: targetKind,
            targetReferenceID: targetReferenceID,
            explanation:
              "Orbit skipped \(participant.displayName) because group expansion only targets AI workspace personas in the first M4 slice."
          )
        )
        continue
      }

      guard participant.availability != .idle else {
        excludedParticipantReasons.append(
          excludedReason(
            displayName: participant.displayName,
            participantID: participant.id,
            workspacePersonaID: participant.workspacePersonaID,
            reasonCategory: .personaUnavailable,
            targetKind: targetKind,
            targetReferenceID: targetReferenceID,
            explanation:
              "Orbit skipped \(participant.displayName) because the persisted workspace persona is not currently available for expansion."
          )
        )
        continue
      }

      includedParticipants.append(participant)
      includedParticipantReasons.append(
        OrbitTargetParticipantReason(
          participantID: participant.id,
          workspacePersonaID: participant.workspacePersonaID,
          displayName: participant.displayName,
          reasonCategory: includedReasonCategory,
          sourceTargetKind: targetKind,
          sourceTargetReferenceID: targetReferenceID,
          explanation:
            "Orbit included \(participant.displayName) through persisted \(targetKind.rawValue) membership for \(targetDisplayName)."
        )
      )
    }

    if includedParticipants.isEmpty {
      return OrbitTargetResolution(
        status: .empty,
        targetKind: targetKind,
        targetReferenceID: targetReferenceID,
        targetDisplayName: targetDisplayName,
        workspaceID: workspace.id,
        includedParticipants: [],
        includedParticipantReasons: [],
        excludedParticipantReasons: excludedParticipantReasons,
        outcomeReasonCategory: .emptyGroup,
        outcomeExplanation:
          "\(targetDisplayName) has no eligible workspace persona members in workspace \(workspace.id)."
      )
    }

    return OrbitTargetResolution(
      status: .resolved,
      targetKind: targetKind,
      targetReferenceID: targetReferenceID,
      targetDisplayName: targetDisplayName,
      workspaceID: workspace.id,
      includedParticipants: includedParticipants,
      includedParticipantReasons: includedParticipantReasons,
      excludedParticipantReasons: excludedParticipantReasons,
      outcomeReasonCategory: nil,
      outcomeExplanation: nil
    )
  }

  private static func excludedReason(
    displayName: String,
    participantID: String? = nil,
    workspacePersonaID: String? = nil,
    reasonCategory: OrbitTargetReasonCategory,
    targetKind: OrbitAddressedTargetKind,
    targetReferenceID: String,
    explanation: String
  ) -> OrbitTargetParticipantReason {
    OrbitTargetParticipantReason(
      participantID: participantID,
      workspacePersonaID: workspacePersonaID,
      displayName: displayName,
      reasonCategory: reasonCategory,
      sourceTargetKind: targetKind,
      sourceTargetReferenceID: targetReferenceID,
      explanation: explanation
    )
  }

  private static func participantLines(
    title: String,
    reasons: [OrbitTargetParticipantReason]
  ) -> String {
    guard !reasons.isEmpty else {
      return "\(title): none"
    }

    let entries = reasons.map { reason in
      "- \(reason.displayName) | reasonCategory=\(reason.reasonCategory.rawValue) | sourceTargetKind=\(reason.sourceTargetKind.rawValue) | sourceTargetReferenceID=\(reason.sourceTargetReferenceID) | \(reason.explanation)"
    }

    return ([ "\(title):" ] + entries).joined(separator: "\n")
  }

  private static func participantStateLines(
    in workspace: OrbitWorkspace,
    targetResolution: OrbitTargetResolution,
    stateByParticipantID: [String: OrbitGroupParticipantState]
  ) -> String? {
    guard
      targetResolution.status == .resolved,
      targetResolution.targetKind != .collaborator,
      !targetResolution.includedParticipants.isEmpty
    else {
      return nil
    }

    let entries = targetResolution.includedParticipants.map { participant in
      let state = stateByParticipantID[participant.id] ?? .pending
      let role = groupParticipantRole(
        for: participant,
        in: workspace,
        targetResolution: targetResolution
      )

      return "- \(participant.displayName) | role=\(role.rawValue) | state=\(state.rawValue)"
    }

    return ([ "participant states:" ] + entries).joined(separator: "\n")
  }

  private static func groupParticipantRole(
    for participant: OrbitParticipant,
    in workspace: OrbitWorkspace,
    targetResolution: OrbitTargetResolution
  ) -> OrbitGroupParticipantRole {
    guard targetResolution.targetKind != .collaborator else {
      return .contributor
    }

    if participant.personaTemplateID == "venture-product-steward" {
      return .reviewer
    }

    guard let workspacePersonaID = participant.workspacePersonaID else {
      return .contributor
    }

    let matchingMembership = workspace.workspacePersonaMemberships
      .filter { membership in
        guard membership.workspacePersonaID == workspacePersonaID else {
          return false
        }

        switch targetResolution.targetKind {
        case .team:
          return membership.teamID == workspace.team(slug: targetResolution.targetReferenceID)?.id
        case .squad:
          return membership.squadID == workspace.squad(slug: targetResolution.targetReferenceID)?.id
        case .collaborator:
          return false
        }
      }
      .sorted { lhs, rhs in
        if lhs.workspacePersonaID == rhs.workspacePersonaID {
          return lhs.id < rhs.id
        }
        return lhs.workspacePersonaID < rhs.workspacePersonaID
      }
      .first

    if matchingMembership?.roleInGroup == OrbitGroupParticipantRole.reviewer.rawValue {
      return .reviewer
    }

    return .contributor
  }

  private static func exchangeState(
    for targetResolution: OrbitTargetResolution,
    stateByParticipantID: [String: OrbitGroupParticipantState]
  ) -> OrbitGroupExchangeState {
    let participantStates = targetResolution.includedParticipants.map {
      stateByParticipantID[$0.id] ?? .pending
    }

    if participantStates.contains(.pending) {
      return .active
    }

    let repliedCount = participantStates.filter { $0 == .replied }.count
    let failedCount = participantStates.filter { $0 == .failed }.count

    if repliedCount == participantStates.count {
      return .completed
    }

    if repliedCount > 0 && failedCount > 0 {
      return .partial
    }

    return .failed
  }

  private static func orderedUniqueMemberships(
    from memberships: [OrbitWorkspacePersonaMembership]
  ) -> [OrbitWorkspacePersonaMembership] {
    let orderedMemberships = memberships.sorted { lhs, rhs in
      if lhs.workspacePersonaID == rhs.workspacePersonaID {
        return lhs.id < rhs.id
      }
      return lhs.workspacePersonaID < rhs.workspacePersonaID
    }
    var seenWorkspacePersonaIDs = Set<String>()

    return orderedMemberships.filter { membership in
      seenWorkspacePersonaIDs.insert(membership.workspacePersonaID).inserted
    }
  }
}
