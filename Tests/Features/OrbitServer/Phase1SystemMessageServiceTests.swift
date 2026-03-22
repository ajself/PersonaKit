import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1SystemMessageServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func appendSystemMessageCreatesVisibleSystemEventAndRealtimeProjection() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_520)
    let recorder = SystemMessageAppendRecorder()
    let service = OrbitPhase1SystemMessageService(
      loadSnapshot: { _, _, _ in sampleSnapshot() },
      appendMessage: { workspaceID, message, realtimeEvents, _, _ in
        await recorder.record(
          workspaceID: workspaceID,
          message: message,
          realtimeEvents: realtimeEvents
        )
      },
      now: { createdAt },
      makeMessageID: { UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")! }
    )

    let result = try await service.appendSystemMessage(
      OrbitPhase1AppendSystemMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        body: "AJ invited Samwise and ProdDoc into the active lightweight meeting."
      )
    )

    #expect(await recorder.workspaceID == workspaceID)
    #expect(await recorder.message?.authorType == .system)
    #expect(await recorder.message?.body.contains("lightweight meeting") == true)
    #expect(await recorder.realtimeEvents.map(\.category) == [.messageCreated, .threadActivityUpdated])
    #expect(result.snapshot.messages.count == 2)
    #expect(result.snapshot.messages.last?.authorType == .system)
  }

  @Test
  func appendSystemMessageDoesNotActivateCreatedMeetingState() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_520)
    let recorder = SystemMessageAppendRecorder()
    let service = OrbitPhase1SystemMessageService(
      loadSnapshot: { _, _, _ in sampleCreatedMeetingSnapshot() },
      appendMessage: { workspaceID, message, realtimeEvents, meetingState, _ in
        await recorder.record(
          workspaceID: workspaceID,
          message: message,
          realtimeEvents: realtimeEvents,
          meetingState: meetingState
        )
      },
      now: { createdAt },
      makeMessageID: { UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")! }
    )

    let result = try await service.appendSystemMessage(
      OrbitPhase1AppendSystemMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        body: "System bookkeeping should not start the meeting."
      )
    )

    #expect(await recorder.meetingState?.status == .created)
    #expect(result.snapshot.meetingState?.status == .created)
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
          id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Trigger message",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ]
    )
  }

  private func sampleCreatedMeetingSnapshot() -> OrbitPhase1RoomSnapshot {
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
        postType: .meeting,
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
          id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Trigger message",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: "workspace-persona-orbit-samwise",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405),
          participationMode: .active
        )
      ],
      meetingState: OrbitMeetingStateRecord(
        postID: postID,
        meetingType: .team,
        status: .created,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
          meetingPostID: postID,
          postParticipantID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405)
        )
      ]
    )
  }
}

private actor SystemMessageAppendRecorder {
  var workspaceID: UUID?
  var message: OrbitMessageRecord?
  var realtimeEvents = [OrbitRealtimeEventRecord]()
  var meetingState: OrbitMeetingStateRecord?

  func record(
    workspaceID: UUID,
    message: OrbitMessageRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    meetingState: OrbitMeetingStateRecord? = nil
  ) {
    self.workspaceID = workspaceID
    self.message = message
    self.realtimeEvents = realtimeEvents
    self.meetingState = meetingState
  }
}
