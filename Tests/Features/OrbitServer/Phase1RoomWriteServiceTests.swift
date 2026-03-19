import Foundation
import Testing

@testable import OrbitServerRuntime

actor AppendRecorder {
  var workspaceID: UUID?
  var message: OrbitMessageRecord?
  var events = [OrbitRealtimeEventRecord]()

  func record(
    workspaceID: UUID,
    message: OrbitMessageRecord,
    events: [OrbitRealtimeEventRecord]
  ) {
    self.workspaceID = workspaceID
    self.message = message
    self.events = events
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
      appendMessage: { workspaceID, message, realtimeEvents, _ in
        await recorder.record(
          workspaceID: workspaceID,
          message: message,
          events: realtimeEvents
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
  func appendUserMessageFailsWhenRoomIsMissing() async {
    let service = OrbitPhase1RoomWriteService(
      loadSnapshot: { _, _ in nil },
      appendMessage: { _, _, _, _ in
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
}
