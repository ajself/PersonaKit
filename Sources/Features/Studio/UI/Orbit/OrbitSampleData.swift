import Foundation

extension OrbitWorkspace {
  static let defaultWorkspace = OrbitWorkspace(
    id: "orbit",
    displayName: "Orbit",
    purpose: "Command center for persistent AI collaborators working with AJ.",
    participants: [
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
      ),
      OrbitParticipant(
        id: OrbitParticipantID.samwise.rawValue,
        workspacePersonaID: "workspace-persona-orbit-samwise",
        displayName: "Samwise",
        roleLabel: "Trusted Partner",
        participantType: .ai,
        personaTemplateID: "samwise",
        defaultDirectiveID: "maintain-partner-sync-and-handoffs",
        requiredSkillIDs: ["codex-cli"],
        authorizedSkillIDs: ["codex-cli"],
        availability: .available,
        sortOrder: 2
      ),
      OrbitParticipant(
        id: OrbitParticipantID.prodDoc.rawValue,
        workspacePersonaID: "workspace-persona-orbit-proddoc",
        displayName: "ProdDoc",
        roleLabel: "Product",
        participantType: .ai,
        personaTemplateID: "venture-product-steward",
        defaultDirectiveID: "run-venture-product-planning",
        requiredSkillIDs: ["codex-cli"],
        authorizedSkillIDs: ["codex-cli"],
        availability: .available,
        sortOrder: 3
      ),
    ],
    teams: [
      OrbitTeam(
        id: "team-founding-group",
        workspaceID: "orbit",
        slug: OrbitAddressTargetID.foundingGroup.rawValue,
        name: OrbitAddressTargetID.foundingGroup.displayText,
        purpose: "Seeded first team target for the Orbit command center.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      )
    ],
    squads: [
      OrbitSquad(
        id: "squad-command-center-feedback",
        workspaceID: "orbit",
        teamID: "team-founding-group",
        slug: "command-center-feedback-squad",
        name: "Command Center Feedback Squad",
        purpose: "Focused feedback lane for the current Orbit surface.",
        createdAt: Date(timeIntervalSince1970: 1_742_342_401)
      )
    ],
    workspacePersonaMemberships: [
      OrbitWorkspacePersonaMembership(
        id: "membership-samwise-founding-group",
        workspacePersonaID: "workspace-persona-orbit-samwise",
        teamID: "team-founding-group",
        squadID: nil,
        roleInGroup: "trusted-partner",
        createdAt: Date(timeIntervalSince1970: 1_742_342_402)
      ),
      OrbitWorkspacePersonaMembership(
        id: "membership-proddoc-founding-group",
        workspacePersonaID: "workspace-persona-orbit-proddoc",
        teamID: "team-founding-group",
        squadID: nil,
        roleInGroup: "product-steward",
        createdAt: Date(timeIntervalSince1970: 1_742_342_403)
      ),
      OrbitWorkspacePersonaMembership(
        id: "membership-proddoc-feedback-squad",
        workspacePersonaID: "workspace-persona-orbit-proddoc",
        teamID: nil,
        squadID: "squad-command-center-feedback",
        roleInGroup: "reviewer",
        createdAt: Date(timeIntervalSince1970: 1_742_342_404)
      ),
    ],
    activeThreadID: "thread-0001",
    threads: [
      OrbitConversationThread(
        id: "thread-0001",
        title: "Orbit MVP Checkpoint",
        interactionMode: .lightweightMeeting,
        createdSequence: 1,
        updatedSequence: 1,
        messages: [
          OrbitMessage(
            id: "msg-0001",
            speakerParticipantID: OrbitParticipantID.samwise.rawValue,
            addressedParticipantID: nil,
            body:
              "Orbit is ready for the first checkpoint. Start with workspace, roster, conversation, and trace.",
            order: 1,
            kind: .participantResponse
          )
        ]
      )
    ],
    activationRecords: [
      OrbitActivationRecord(
        id: "act-0001",
        workspaceID: "orbit",
        responseMessageID: "msg-0001",
        participantID: OrbitParticipantID.samwise.rawValue,
        workspacePersonaID: "workspace-persona-orbit-samwise",
        personaTemplateID: "samwise",
        directiveID: "maintain-partner-sync-and-handoffs",
        responseMode: .lightweightMeeting,
        triggerSource: .generalThreadReply,
        triggerMessageID: nil,
        memoryInfluenced: false,
        memorySourceRefs: []
      )
    ],
    activationContractSnapshots: [
      OrbitActivationContractSnapshot(
        id: "act-0001-contract",
        activationID: "act-0001",
        directiveSource: .participantDefault,
        kitIDs: ["trusted-partner-core"],
        authorizedSkillIDs: ["codex-cli"],
        stopPointIDs: [],
        reviewGateIDs: ["intent:partner-sync-review"],
        memoryScopeIDs: []
      )
    ],
    activationFailureRecords: [],
    meetingPromotionRecords: [],
    meetingContinuityRecords: [],
    nextMessageSequence: 2,
    nextActivationSequence: 2,
    nextActivationFailureSequence: 1
  )
}
