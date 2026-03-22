import Foundation
import Testing

@testable import OrbitServerRuntime

actor AppendRecorder {
  var workspaceID: UUID?
  var message: OrbitMessageRecord?
  var events = [OrbitRealtimeEventRecord]()
  var meetingState: OrbitMeetingStateRecord?

  func record(
    workspaceID: UUID,
    message: OrbitMessageRecord,
    events: [OrbitRealtimeEventRecord],
    meetingState: OrbitMeetingStateRecord?
  ) {
    self.workspaceID = workspaceID
    self.message = message
    self.events = events
    self.meetingState = meetingState
  }
}

struct Phase1RoomWriteServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func appendUserMessageCreatesCanonicalMessageAndUpdatedSnapshot() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_500)
    let recorder = AppendRecorder()
    let service = OrbitPhase1RoomWriteService(
      loadSnapshot: { _, _ in sampleRoomSnapshot() },
      appendMessage: { workspaceID, message, realtimeEvents, meetingState, _ in
        await recorder.record(
          workspaceID: workspaceID,
          message: message,
          events: realtimeEvents,
          meetingState: meetingState
        )
      },
      now: { createdAt },
      makeMessageID: { UUID(uuidString: "55555555-5555-5555-5555-555555555555")! }
    )

    let result = try await service.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        authorID: "aj",
        body: "Canonical write path"
      )
    )

    #expect(await recorder.workspaceID == workspaceID)
    #expect(await recorder.message?.body == "Canonical write path")
    #expect(await recorder.events.count == 2)
    #expect(await recorder.events.map(\.category) == [.messageCreated, .threadActivityUpdated])
    #expect(result.snapshot.messages.count == 2)
    #expect(result.snapshot.thread.lastActivityAt == createdAt)
  }

  @Test
  func appendUserMessagePreservesMeetingRuntimeRecords() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_500)
    let service = OrbitPhase1RoomWriteService(
      loadSnapshot: { _, _ in sampleMeetingRoomSnapshot() },
      appendMessage: { _, _, _, _, _ in },
      now: { createdAt },
      makeMessageID: { UUID(uuidString: "55555555-5555-5555-5555-555555555555")! }
    )

    let result = try await service.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        authorID: "aj",
        body: "Meeting state should persist."
      )
    )

    #expect(result.snapshot.meetingState == sampleMeetingRoomSnapshot().meetingState)
    #expect(result.snapshot.meetingMembers == sampleMeetingRoomSnapshot().meetingMembers)
  }

  @Test
  func appendUserMessageActivatesCreatedMeetingState() async throws {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_500)
    let recorder = AppendRecorder()
    let service = OrbitPhase1RoomWriteService(
      loadSnapshot: { _, _ in sampleCreatedMeetingRoomSnapshot() },
      appendMessage: { workspaceID, message, realtimeEvents, meetingState, _ in
        await recorder.record(
          workspaceID: workspaceID,
          message: message,
          events: realtimeEvents,
          meetingState: meetingState
        )
      },
      now: { createdAt },
      makeMessageID: { UUID(uuidString: "99999999-9999-9999-9999-999999999999")! }
    )

    let result = try await service.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        authorID: "aj",
        body: "Meeting starts now."
      )
    )

    #expect(await recorder.meetingState?.status == .active)
    #expect(result.snapshot.meetingState?.status == .active)
  }

  @Test
  func appendUserMessageFailsWhenRoomIsMissing() async {
    let service = OrbitPhase1RoomWriteService(
      loadSnapshot: { _, _ in nil },
      appendMessage: { _, _, _, _, _ in
        Issue.record("appendMessage should not be called when room is missing")
      }
    )

    do {
      _ = try await service.appendUserMessage(
        OrbitPhase1AppendUserMessageRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          authorID: "aj",
          body: "No room"
        )
      )
      Issue.record("Expected room-not-found error")
    } catch let error as OrbitPhase1RoomWriteServiceError {
      #expect(error == .roomNotFound)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func sampleRoomSnapshot() -> OrbitPhase1RoomSnapshot {
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
          id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Orbit room bootstrapped.",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: Date(timeIntervalSince1970: 1_742_342_410),
          updatedAt: Date(timeIntervalSince1970: 1_742_342_410)
        )
      ]
    )
  }

  private func sampleMeetingRoomSnapshot() -> OrbitPhase1RoomSnapshot {
    let snapshot = sampleRoomSnapshot()

    return OrbitPhase1RoomSnapshot(
      workspace: snapshot.workspace,
      channel: snapshot.channel,
      post: OrbitPostRecord(
        id: snapshot.post.id,
        workspaceID: snapshot.post.workspaceID,
        channelID: snapshot.post.channelID,
        postType: .meeting,
        createdByParticipantType: snapshot.post.createdByParticipantType,
        createdByParticipantID: snapshot.post.createdByParticipantID,
        title: snapshot.post.title,
        status: snapshot.post.status,
        createdAt: snapshot.post.createdAt,
        archivedAt: snapshot.post.archivedAt
      ),
      thread: snapshot.thread,
      messages: snapshot.messages,
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
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
        status: .active,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
          meetingPostID: postID,
          postParticipantID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
          participationRole: .contributor,
          selectedReason: "Selected via founding-group checkpoint scope.",
          joinedAt: Date(timeIntervalSince1970: 1_742_342_405)
        )
      ]
    )
  }

  private func sampleCreatedMeetingRoomSnapshot() -> OrbitPhase1RoomSnapshot {
    let snapshot = sampleMeetingRoomSnapshot()

    return OrbitPhase1RoomSnapshot(
      workspace: snapshot.workspace,
      channel: snapshot.channel,
      post: snapshot.post,
      thread: snapshot.thread,
      messages: snapshot.messages,
      postParticipants: snapshot.postParticipants,
      meetingState: OrbitMeetingStateRecord(
        postID: postID,
        meetingType: .team,
        status: .created,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      meetingMembers: snapshot.meetingMembers
    )
  }
}
