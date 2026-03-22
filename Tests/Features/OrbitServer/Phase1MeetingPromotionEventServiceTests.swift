import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1MeetingPromotionEventServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func appendMeetingPromotionEventCreatesBoundedAttemptEvidence() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_520)
    let recorder = MeetingPromotionAppendRecorder()
    let service = OrbitPhase1MeetingPromotionEventService(
      loadSnapshot: { _, _, _ in sampleSnapshot() },
      appendPostEvent: { workspaceID, postEvent, realtimeEvents in
        await recorder.record(
          workspaceID: workspaceID,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents
        )
      },
      appendFailure: { _, _, _, _, _, _ in
        Issue.record("Failure appender should not run for attempt evidence")
      },
      now: { createdAt },
      makePostEventID: { UUID(uuidString: "55555555-5555-5555-5555-555555555555")! }
    )

    let result = try await service.appendMeetingPromotionEvent(
      OrbitPhase1AppendMeetingPromotionEventRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        promotion: OrbitPhase1MeetingPromotionEventPayload(
          initiatedByParticipantID: "aj",
          addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
          addressedTargetReferenceID: "founding-group",
          targetDisplayName: "Founding Group",
          meetingType: OrbitMeetingType.team.rawValue,
          title: "Founding Group Meeting",
          memberWorkspacePersonaIDs: [
            UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          ]
        )
      )
    )

    #expect(await recorder.workspaceID == workspaceID)
    #expect(await recorder.postEvent?.eventType == OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue)
    #expect(await recorder.realtimeEvents.map(\.category) == [.meetingPromotionAttempted])
    let payload = try #require(await recorder.payload)
    #expect(payload.title == "Founding Group Meeting")
    #expect(payload.failure == nil)
    #expect(result.systemMessage == nil)
    #expect(result.snapshot.postEvents.last?.eventType == OrbitPhase1RealtimeEventCategory.meetingPromotionAttempted.rawValue)
    #expect(result.snapshot.messages.isEmpty)
  }

  @Test
  func appendMeetingPromotionEventCreatesFailureEvidenceAndVisibleSystemMessage() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_620)
    let recorder = MeetingPromotionAppendRecorder()
    let systemMessageID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    let service = OrbitPhase1MeetingPromotionEventService(
      loadSnapshot: { _, _, _ in sampleSnapshot() },
      appendPostEvent: { _, _, _ in
        Issue.record("Post-event appender should not run for failure evidence")
      },
      appendFailure: { workspaceID, systemMessage, postEvent, realtimeEvents, _, _ in
        await recorder.record(
          workspaceID: workspaceID,
          systemMessage: systemMessage,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents
        )
      },
      now: { createdAt },
      makePostEventID: { UUID(uuidString: "99999999-9999-9999-9999-999999999999")! }
    )

    let result = try await service.appendMeetingPromotionEvent(
      OrbitPhase1AppendMeetingPromotionEventRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        promotion: OrbitPhase1MeetingPromotionEventPayload(
          initiatedByParticipantID: "aj",
          addressedTargetKind: OrbitAddressedTargetKind.team.rawValue,
          addressedTargetReferenceID: "founding-group",
          targetDisplayName: "Founding Group",
          meetingType: OrbitMeetingType.team.rawValue,
          title: "Founding Group Meeting",
          memberWorkspacePersonaIDs: [
            UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          ],
          failure: OrbitPhase1MeetingPromotionFailurePayload(
            systemEventMessageID: systemMessageID,
            systemEventBody: "Orbit meeting promotion failed",
            detail: "The operation could not be completed."
          )
        )
      )
    )

    #expect(await recorder.workspaceID == workspaceID)
    #expect(await recorder.systemMessage?.id == systemMessageID)
    #expect(await recorder.postEvent?.eventType == OrbitPhase1RealtimeEventCategory.meetingPromotionFailed.rawValue)
    let realtimeCategories = await recorder.realtimeEvents.map(\.category)
    #expect(realtimeCategories.count == 3)
    #expect(realtimeCategories.contains(.messageCreated))
    #expect(realtimeCategories.contains(.threadActivityUpdated))
    #expect(realtimeCategories.contains(.meetingPromotionFailed))
    let payload = try #require(await recorder.payload)
    #expect(payload.failure?.systemEventMessageID == systemMessageID)
    #expect(payload.failure?.detail == "The operation could not be completed.")
    #expect(result.systemMessage?.id == systemMessageID)
    #expect(result.snapshot.messages.last?.id == systemMessageID)
    #expect(result.snapshot.postEvents.last?.eventType == OrbitPhase1RealtimeEventCategory.meetingPromotionFailed.rawValue)
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
      messages: []
    )
  }
}

private actor MeetingPromotionAppendRecorder {
  private(set) var workspaceID: UUID?
  private(set) var systemMessage: OrbitMessageRecord?
  private(set) var postEvent: OrbitPostEventRecord?
  private(set) var realtimeEvents = [OrbitRealtimeEventRecord]()
  private(set) var payload: OrbitPhase1MeetingPromotionEventPayload?

  func record(
    workspaceID: UUID,
    systemMessage: OrbitMessageRecord? = nil,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord]
  ) async {
    self.workspaceID = workspaceID
    self.systemMessage = systemMessage
    self.postEvent = postEvent
    self.realtimeEvents = realtimeEvents
    self.payload = try? OrbitPhase1RealtimeEventPayloadCodec.decode(
      OrbitPhase1MeetingPromotionEventPayload.self,
      from: postEvent.payloadJSON
    )
  }
}
