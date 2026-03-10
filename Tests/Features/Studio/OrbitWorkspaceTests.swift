import Foundation
import Testing

@testable import StudioFeatures

struct OrbitWorkspaceTests {
  @Test
  func workspaceRoundTripPreservesMessagesAndActivationTrace() throws {
    var workspace = OrbitWorkspace.defaultWorkspace
    workspace.appendConversationTurn(
      body: "Founding group, lock the next command-center pass.",
      addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(workspace)
    let decoded = try JSONDecoder().decode(OrbitWorkspace.self, from: data)

    #expect(decoded == workspace)
    #expect(decoded.activeThread?.messages.count == workspace.activeThread?.messages.count)
    #expect(decoded.activationRecords.count == workspace.activationRecords.count)
  }

  @Test
  func directAddressCreatesParticipantResponseAndActivationTrace() throws {
    var workspace = OrbitWorkspace.defaultWorkspace

    let createdMessages = workspace.appendConversationTurn(
      body: "Samwise, line up the next checkpoint step.",
      addressedParticipantID: OrbitParticipantID.samwise.rawValue
    )

    #expect(createdMessages.count == 2)

    let userMessage = try #require(createdMessages.first)
    let responseMessage = try #require(createdMessages.last)
    let activation = try #require(workspace.activationRecord(for: responseMessage.id))

    #expect(userMessage.kind == .user)
    #expect(responseMessage.kind == .participantResponse)
    #expect(responseMessage.speakerParticipantID == OrbitParticipantID.samwise.rawValue)
    #expect(responseMessage.addressedParticipantID == OrbitParticipantID.aj.rawValue)
    #expect(activation.participantID == OrbitParticipantID.samwise.rawValue)
    #expect(activation.personaID == "samwise")
    #expect(activation.directiveID == "maintain-partner-sync-and-handoffs")
    #expect(activation.triggerSource == .directAddress)
    #expect(activation.triggerMessageID == userMessage.id)
    #expect(workspace.activeThread?.interactionMode == .directMessage)
  }

  @Test
  func foundingGroupInvitationCreatesMeetingEventAndMultipleResponses() throws {
    var workspace = OrbitWorkspace.defaultWorkspace

    let createdMessages = workspace.appendConversationTurn(
      body: "Founding group, align on the next Orbit checkpoint.",
      addressedParticipantID: OrbitAddressTargetID.foundingGroup.rawValue
    )

    #expect(createdMessages.count == 4)

    let systemEvent = try #require(
      createdMessages.first(where: { $0.kind == .systemEvent })
    )
    let responseMessages = createdMessages.filter { $0.kind == .participantResponse }
    let activationRecords = workspace.activationRecords.filter {
      responseMessages.map(\.id).contains($0.responseMessageID)
    }

    #expect(systemEvent.body.contains("lightweight meeting"))
    #expect(responseMessages.count == 2)
    #expect(
      Set(responseMessages.map(\.speakerParticipantID)) == [
        OrbitParticipantID.samwise.rawValue,
        OrbitParticipantID.prodDoc.rawValue,
      ]
    )
    #expect(activationRecords.count == 2)
    #expect(activationRecords.allSatisfy { $0.triggerSource == .meetingInvocation })
    #expect(workspace.activeThread?.interactionMode == .lightweightMeeting)
  }
}
