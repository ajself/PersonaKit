import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1ActivationFailureServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  private let triggerMessageID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
  private let systemEventMessageID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

  @Test
  func appendActivationFailureCreatesSystemMessageAndFailureEvent() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_520)
    let recorder = ActivationFailureAppendRecorder()
    let service = OrbitPhase1ActivationFailureService(
      loadSnapshot: { _, _ in sampleSnapshot() },
      appendFailure: { workspaceID, systemMessage, postEvent, realtimeEvents, _ in
        await recorder.record(
          workspaceID: workspaceID,
          systemMessage: systemMessage,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents
        )
      },
      now: { createdAt },
      makePostEventID: { UUID(uuidString: "77777777-7777-7777-7777-777777777777")! }
    )

    let result = try await service.appendActivationFailure(
      OrbitPhase1AppendActivationFailureRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        initiatedByParticipantID: "aj",
        triggerMessageID: triggerMessageID,
        failure: OrbitPhase1ActivationFailurePayload(
          addressedTargetID: "samwise",
          participantID: "samwise",
          workspacePersonaID: systemEventMessageID.uuidString,
          personaTemplateID: "samwise",
          directiveID: "maintain-partner-sync-and-handoffs",
          triggerSource: "directAddress",
          systemEventMessageID: systemEventMessageID,
          requiredSkillIDs: ["codex-cli"],
          authorizedSkillIDs: [],
          failureReason: "unauthorizedSkillPosture",
          systemEventBody: "Orbit blocked the activation because the required skill posture is not authorized for this collaborator."
        )
      )
    )

    #expect(await recorder.workspaceID == workspaceID)
    #expect(await recorder.systemMessage?.id == systemEventMessageID)
    #expect(await recorder.systemMessage?.authorType == .system)
    #expect(await recorder.postEvent?.eventType == OrbitPhase1RealtimeEventCategory.activationFailed.rawValue)
    #expect(await recorder.realtimeEvents.map(\.category).contains(.activationFailed) == true)
    let payload = try #require(await recorder.postEventPayload)
    #expect(payload.failure?.failureReason == "unauthorizedSkillPosture")
    #expect(payload.failure?.systemEventMessageID == systemEventMessageID)
    #expect(result.snapshot.messages.last?.id == systemEventMessageID)
    #expect(result.snapshot.postEvents.last?.eventType == OrbitPhase1RealtimeEventCategory.activationFailed.rawValue)
  }

  private func sampleSnapshot() -> OrbitPhase1RoomSnapshot {
    OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: Date(timeIntervalSince1970: 1_742_342_460),
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      messages: [
        OrbitMessageRecord(
          id: triggerMessageID,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Samwise, use the tool lane for this checkpoint.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ]
    )
  }
}

private actor ActivationFailureAppendRecorder {
  var workspaceID: UUID?
  var systemMessage: OrbitMessageRecord?
  var postEvent: OrbitPostEventRecord?
  var realtimeEvents = [OrbitRealtimeEventRecord]()
  var postEventPayload: OrbitPhase1ActivationEventPayload?

  func record(
    workspaceID: UUID,
    systemMessage: OrbitMessageRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord]
  ) {
    self.workspaceID = workspaceID
    self.systemMessage = systemMessage
    self.postEvent = postEvent
    self.realtimeEvents = realtimeEvents
    self.postEventPayload = try? OrbitPhase1RealtimeEventPayloadCodec.decode(
      OrbitPhase1ActivationEventPayload.self,
      from: postEvent.payloadJSON
    )
  }
}
