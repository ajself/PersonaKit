import Foundation

extension OrbitWorkspace {
  static let defaultWorkspace = OrbitWorkspace(
    id: "orbit",
    displayName: "Orbit",
    purpose: "Command center for persistent AI collaborators working with AJ.",
    participants: [
      OrbitParticipant(
        id: OrbitParticipantID.aj.rawValue,
        displayName: "AJ",
        roleLabel: "Founder",
        participantType: .human,
        personaID: nil,
        defaultDirectiveID: nil,
        availability: .active,
        sortOrder: 1
      ),
      OrbitParticipant(
        id: OrbitParticipantID.samwise.rawValue,
        displayName: "Samwise",
        roleLabel: "Trusted Partner",
        participantType: .ai,
        personaID: "samwise",
        defaultDirectiveID: "maintain-partner-sync-and-handoffs",
        availability: .available,
        sortOrder: 2
      ),
      OrbitParticipant(
        id: OrbitParticipantID.prodDoc.rawValue,
        displayName: "ProdDoc",
        roleLabel: "Product",
        participantType: .ai,
        personaID: "venture-product-steward",
        defaultDirectiveID: "run-venture-product-planning",
        availability: .available,
        sortOrder: 3
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
        responseMessageID: "msg-0001",
        participantID: OrbitParticipantID.samwise.rawValue,
        personaID: "samwise",
        directiveID: "maintain-partner-sync-and-handoffs",
        triggerSource: .generalThreadReply,
        triggerMessageID: nil,
        memoryInfluenced: false
      )
    ],
    nextMessageSequence: 2,
    nextActivationSequence: 2
  )
}
