import Foundation
import Testing

@testable import OrbitServerRuntime

struct Phase1RealtimeSubscriptionAdapterTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

  @Test
  func startBootstrapsWhenNoCursorIsProvided() async throws {
    let snapshot = sampleSnapshot()
    let adapter = OrbitPhase1RealtimeSubscriptionAdapter(
      feedService: OrbitPhase1RealtimeFeedService(
        loadSnapshot: { _ in snapshot },
        loadReplayBatch: { _, _ in
          Issue.record("Replay loader should not run without a cursor")
          return OrbitPhase1RealtimeReplayBatch(events: [])
        }
      )
    )

    let result = try await adapter.start(
      handshake: OrbitPhase1SubscriptionHandshake(
        scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center")
      )
    )

    #expect(result == .bootstrap(snapshot))
  }

  @Test
  func startReturnsReplayWhenCursorIsValidAndNewEventsExist() async throws {
    let snapshot = sampleSnapshot()
    let event = OrbitPhase1RealtimeEventEnvelope(
      id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      workspaceID: workspaceID,
      category: .messageCreated,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      payloadJSON: "{}"
    )
    let nextCursor = OrbitPhase1ReplayCursor(
      workspaceID: workspaceID,
      lastEventID: event.id,
      lastEventCreatedAt: event.createdAt
    )
    let adapter = OrbitPhase1RealtimeSubscriptionAdapter(
      feedService: OrbitPhase1RealtimeFeedService(
        loadSnapshot: { _ in snapshot },
        loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: [event]) }
      )
    )

    let result = try await adapter.start(
      handshake: OrbitPhase1SubscriptionHandshake(
        scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
        cursor: snapshot.replayCursor
      )
    )

    #expect(result == .replay([event], nextCursor: nextCursor))
  }

  @Test
  func startRequestsResyncWhenCursorWorkspaceDoesNotMatchSnapshot() async throws {
    let snapshot = sampleSnapshot()
    let adapter = OrbitPhase1RealtimeSubscriptionAdapter(
      feedService: OrbitPhase1RealtimeFeedService(
        loadSnapshot: { _ in snapshot },
        loadReplayBatch: { _, _ in OrbitPhase1RealtimeReplayBatch(events: []) }
      )
    )

    let result = try await adapter.start(
      handshake: OrbitPhase1SubscriptionHandshake(
        scope: OrbitPhase1RealtimeSubscriptionScope(workspaceSlug: "orbit", channelSlug: "command-center"),
        cursor: OrbitPhase1ReplayCursor(workspaceID: UUID())
      )
    )

    #expect(result == .resync(snapshot, reason: .workspaceMismatch))
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let room = OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      channel: OrbitChannelRecord(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      post: OrbitPostRecord(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        workspaceID: workspaceID,
        channelID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Orbit room",
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1_742_342_400)
      ),
      thread: OrbitThreadRecord(
        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        postID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
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
        lastEventID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        lastEventCreatedAt: Date(timeIntervalSince1970: 1_742_342_460)
      )
    )
  }
}
