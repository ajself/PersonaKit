import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1RealtimeFeedServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

  @Test
  func bootstrapReturnsSnapshotForSubscriptionScope() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { scope in
        #expect(scope == OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"))
        return snapshot
      },
      loadReplayBatch: { _, _ in
        Issue.record("Replay loader should not run during bootstrap")
        return OrbitPhase1RealtimeReplayBatch(events: [])
      }
    )

    let result = try await service.bootstrap(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center")
    )

    #expect(result == snapshot)
  }

  @Test
  func replayReturnsDeterministicallyOrderedNewEventsAndCursor() async throws {
    let cursorAnchor = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400),
      payloadJSON: "{}"
    )
    let newerSameTimestamp = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .threadActivityUpdated,
      createdAt: cursorAnchor.createdAt,
      payloadJSON: "{}"
    )
    let newest = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
      workspaceID: workspaceID,
      postID: postID,
      threadID: threadID,
      category: .activationResolved,
      createdAt: Date(timeIntervalSince1970: 1_742_342_460),
      payloadJSON: "{}"
    )
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in nil },
      loadReplayBatch: { _, cursor in
        #expect(cursor.lastEventID == cursorAnchor.id)
        return OrbitPhase1RealtimeReplayBatch(events: [newest, cursorAnchor, newerSameTimestamp])
      }
    )

    let result = try await service.replay(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      cursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: cursorAnchor.id,
        lastEventCreatedAt: cursorAnchor.createdAt
      )
    )

    switch result {
    case .events(let events, let nextCursor):
      #expect(events == [newerSameTimestamp, newest])
      #expect(nextCursor.lastEventID == newest.id)
      #expect(nextCursor.lastEventCreatedAt == newest.createdAt)
    default:
      Issue.record("Expected replay events result")
    }
  }

  @Test
  func replayReturnsNoChangeWhenNoNewEventsExist() async throws {
    let cursor = OrbitPhase1ReplayCursor(
      workspaceID: workspaceID,
      lastEventID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
      lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_400)
    )
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in nil },
      loadReplayBatch: { _, _ in
        OrbitPhase1RealtimeReplayBatch(events: [])
      }
    )

    let result = try await service.replay(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      cursor: cursor
    )

    #expect(result == .noChange(cursor: cursor))
  }

  @Test
  func replayRequestsResyncWhenGapIsDetected() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!)
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in snapshot },
      loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [], hasGap: true) }
    )

    let result = try await service.replay(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      cursor: OrbitPhase1ReplayCursor(workspaceID: workspaceID)
    )

    #expect(result == .resync(snapshot: snapshot, reason: .gapDetected))
  }

  @Test
  func validateRequestsWorkspaceMismatchResyncWhenSnapshotChangesWorkspace() {
    let snapshot = sampleSnapshot(cursorEventID: UUID())
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in snapshot },
      loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
    )

    let mismatch = service.validate(
      snapshot: snapshot,
      against: OrbitPhase1ReplayCursor(workspaceID: UUID())
    )

    #expect(mismatch == .workspaceMismatch)
  }

  @Test
  func replayRequestsResyncWhenBatchContainsDifferentWorkspace() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID())
    let mismatchedEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!,
      workspaceID: UUID(),
      postID: postID,
      threadID: threadID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400),
      payloadJSON: "{}"
    )
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in snapshot },
      loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [mismatchedEvent]) }
    )

    let result = try await service.replay(
      scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
      cursor: OrbitPhase1ReplayCursor(workspaceID: workspaceID)
    )

    #expect(result == .resync(snapshot: snapshot, reason: .inconsistentReplayBatch))
  }

  @Test
  func replayRequestsResyncWhenPostScopedBatchContainsDifferentPost() async throws {
    let snapshot = sampleSnapshot(cursorEventID: UUID())
    let mismatchedEvent = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "abababab-abab-abab-abab-abababababab")!,
      workspaceID: workspaceID,
      postID: UUID(uuidString: "99999999-aaaa-bbbb-cccc-dddddddddddd")!,
      threadID: threadID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_400),
      payloadJSON: "{}"
    )
    let service = OrbitPhase1RealtimeFeedService(
      loadSnapshot: { _ in snapshot },
      loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [mismatchedEvent]) }
    )

    let result = try await service.replay(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: postID
      ),
      cursor: OrbitPhase1ReplayCursor(workspaceID: workspaceID)
    )

    #expect(result == .resync(snapshot: snapshot, reason: .inconsistentReplayBatch))
  }

  private func sampleSnapshot(
    cursorEventID: UUID
  ) -> OrbitPhase1RealtimeSnapshot {
    let room = OrbitPhase1RoomSnapshot(
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

    return OrbitPhase1RealtimeSnapshot(
      room: room,
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: cursorEventID,
        lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
      )
    )
  }
}
